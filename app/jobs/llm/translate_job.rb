# frozen_string_literal: true

module LLM
  class TranslateJob < ApplicationJob
    discard_on(FuckyWuckies::TranslateJobFailure) do |_job, error|
      db_chat = error.db_chat
      raise error if db_chat.blank?

      TelegramTools.send_error_message(error, db_chat.api_id)
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def perform(db_chat, text_to_translate, target_language, command_message_from, parent_message_from)
      @db_chat = db_chat
      @command_message_from = command_message_from
      @parent_message_from = parent_message_from
      target_language ||= 'english'

      result_text = llm_translate(text_to_translate, target_language)
      send_output_message(result_text)
    rescue Faraday::Error => e
      model_loading_time = e&.response&.dig(
        :body, 'estimated_time'
      )&.seconds&.in_minutes&.round

      if model_loading_time
        raise FuckyWuckies::TranslateJobFailure.new(
          db_chat: @db_chat,
          severity: Logger::Severity::WARN,
          frontend_message: "--- Model Loading! ---\n" \
                            "API claims it should be ready in ~#{model_loading_time} mins.\n" \
                            'But the API frequently lies so just try again later.'
        ), "Translation model loading, supposedly ready in #{model_loading_time}s: " \
           "chat api_id=#{@db_chat.id} title=#{@db_chat.title}", cause: e
      end

      raise FuckyWuckies::TranslateJobFailure.new(
        db_chat: @db_chat,
        severity: Logger::Severity::ERROR,
        frontend_message: "#{username_header}\n❌ Translation failed :(",
        sticker: :no_french
      ), 'Translation failed: ' \
         "chat api_id=#{@db_chat.id} title=#{@db_chat.title}", cause: e
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    private

    def llm_translate(text, target_language)
      system_prompt = LLMTools.prompt_for_style(:translate)
      user_prompt = "Translate into #{target_language.capitalize}:\n#{text}"

      output = LLMTools.run_chat_completion(
        system_prompt:,
        user_prompt:,
        model_params: {
          model: Rails.application.credentials.openai.translate_model ||
                           Rails.application.credentials.openai.model,
          max_tokens: 512,
          temperature: 0.3
        }
      )

      if output.blank?
        raise FuckyWuckies::TranslateJobFailure.new(
          db_chat: @db_chat,
          severity: Logger::Severity::ERROR,
          frontend_message: "#{username_header}\n❌ Translation failed (blank LLM output)"
        ), 'Translation failed (blank LLM output): ' \
           "chat api_id=#{@db_chat.id} title=#{@db_chat.title}"
      end

      output
    end

    def username_header
      if @parent_message_from && @parent_message_from != @command_message_from
        return "<#{@parent_message_from} via #{@command_message_from}>"
      end

      "<#{@command_message_from}>"
    end

    def send_output_message(translated_text)
      output = "#{username_header}\n#{translated_text}"

      Telegram.bot.send_message(
        chat_id: @db_chat.api_id,
        protect_content: false,
        text: output
      )
      TelegramTools.store_bot_output(@db_chat, output)
    end
  end
end
