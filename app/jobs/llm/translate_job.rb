# frozen_string_literal: true

module LLM
  class TranslateJob < ApplicationJob
    discard_on(FuckyWuckies::TranslateJobFailure) do |_job, error|
      db_chat = error.db_chat
      raise error if db_chat.blank?

      TelegramTools.send_error_message(error, db_chat.api_id)
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def perform(db_chat, text_to_translate, target_language, command_message_from, parent_message_from)
      @db_chat = db_chat
      @command_message_from = command_message_from
      @parent_message_from = parent_message_from

      result_text = LLMProgress.track(@db_chat, label: 'a translation') do |progress|
        llm_translate(text_to_translate, target_language, progress)
      end
      send_output_message(result_text)
    rescue Faraday::Error => e
      model_loading_time = e&.response&.dig( # rubocop:disable Style/SafeNavigationChainLength
        :body, 'estimated_time'              # stfu
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
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    def llm_translate(text, target_language, progress)
      system_prompt = LLMTools.prompt_for_mode(:translate)
      user_prompt = translate_user_prompt(text, target_language)

      TelegramTools.logger.debug("\n##### Translate:\n" \
                                 "### System prompt:\n#{system_prompt}\n" \
                                 "### User prompt:\n#{user_prompt}")

      output = LLMTools.run_chat_completion(
        system_prompt:,
        user_prompt:,
        model_params: { temperature: 0.9 },
        progress:
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

    # target_language is whatever the user asked for, e.g. "french".
    # Without one, the text itself may contain the request (see TranslateHelpers).
    def translate_user_prompt(text, target_language)
      return "Target language/style: #{target_language}\n\n#{text}" if target_language

      <<~PROMPT
        The text below may include a request for a target language or style, like "french ...", "... into french" or "... in chinese".
        If it does, translate the rest of the text accordingly, leaving out the request itself.
        Otherwise, translate the entire text into English.

        #{text}
      PROMPT
    end

    def username_header
      if @parent_message_from && @parent_message_from != @command_message_from
        return "<#{@parent_message_from} via #{@command_message_from}>"
      end

      "<#{@command_message_from}>"
    end

    def send_output_message(translated_text)
      output = "#{username_header}\n#{translated_text}"

      TelegramTools.send_bot_message(@db_chat, output, protect_content: false)
    end
  end
end
