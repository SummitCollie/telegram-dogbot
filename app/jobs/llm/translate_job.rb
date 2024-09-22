# frozen_string_literal: true

module LLM
  class TranslateJob < ApplicationJob
    discard_on(FuckyWuckies::TranslateJobFailure) do |_job, error|
      db_chat = error.db_chat
      raise error if db_chat.blank?

      TelegramTools.send_error_message(error, db_chat.api_id)
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def perform(db_chat, text_to_translate, target_language = 'english')
      result_text = llm_translate(text_to_translate, target_language)
      send_output_message(db_chat, result_text)
    rescue Faraday::Error => e
      model_loading_time = e&.response&.dig(
        :body, 'estimated_time'
      )&.seconds&.in_minutes&.round

      if model_loading_time
        raise FuckyWuckies::TranslateJobFailure.new(
          severity: Logger::Severity::ERROR,
          db_chat:,
          frontend_message: "--- Model Loading! ---\n" \
                            "API claims it should be ready in ~#{model_loading_time} mins.\n" \
                            'But the API frequently lies so just try again later.'
        ), "Translation model loading, supposedly ready in #{model_loading_time}s: " \
           "chat api_id=#{db_chat.id} title=#{db_chat.title}\n#{e}"
      end

      raise FuckyWuckies::TranslateJobFailure.new(
        severity: Logger::Severity::ERROR,
        db_chat:,
        frontend_message: 'Translation failed :(',
        sticker: :no_french
      ), 'Translation failed: ' \
         "chat api_id=#{db_chat.id} title=#{db_chat.title}\n#{e}"
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    def llm_translate(text, target_language)
      client = OpenAI::Client.new
      # client.add_headers('x-wait-for-model' => 'true')

      messages = [
        { role: 'system', content: LLMTools.prompt_for_style(:translate) },
        { role: 'user', content: "Translate into #{target_language.capitalize}:\n#{text}" }
      ]

      result = StringIO.new
      client.chat(parameters: {
                    model: Rails.application.credentials.openai.translate_model ||
                           Rails.application.credentials.openai.model,
                    max_tokens: 512,
                    temperature: 0.3,
                    messages:,
                    stream: proc do |chunk, _bytesize|
                              result << chunk.dig('choices', 0, 'delta', 'content')
                            end
                  })
      output = result.string.strip

      raise FuckyWuckies::SummarizeJobFailure.new, 'Blank output' if output.blank?

      output
    end

    def send_output_message(db_chat, text)
      Telegram.bot.send_message(
        chat_id: db_chat.api_id,
        protect_content: true,
        text:
      )
    end
  end
end
