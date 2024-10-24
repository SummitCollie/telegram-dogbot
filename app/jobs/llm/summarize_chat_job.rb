# frozen_string_literal: true

module LLM
  class SummarizeChatJob < ApplicationJob
    retry_on FuckyWuckies::SummarizeJobError
    rescue_from FuckyWuckies::SummarizeJobFailure, with: :handle_error

    def perform(summary)
      @db_chat = summary.chat
      @style = summary.style

      if executions > 4
        raise FuckyWuckies::SummarizeJobFailure.new(
          severity: Logger::Severity::ERROR,
          db_chat: @db_chat,
          frontend_message: 'Processing failed, sowwy :(',
          sticker: :dead
        ), 'All summarization attempts failed: ' \
           "chat api_id=#{@db_chat.id} title=#{@db_chat.title}"
      end

      messages_to_summarize = @db_chat.messages_to_summarize(summary.summary_type)

      # Each retry, since input didn't fit in LLM context, discard oldest 25% of messages
      if executions > 1
        reduced_count = (messages_to_summarize.size * (1 - ((executions - 1) / 4.0))).floor
        messages_to_summarize = messages_to_summarize.last(reduced_count)
      end

      result_text = llm_summarize(messages_to_summarize, summary.summary_type)

      send_output_message(result_text)
      summary.update!(text: result_text, status: 'complete')
    end

    def self.messages_to_yaml(messages)
      messages.map do |message|
        result = {
          id: message.api_id == -1 ? '?' : message.api_id,
          user: message.user.first_name,
          text: message.text
        }

        result[:attachment] = message.attachment_type.to_s if message.attachment_type.present?

        if !message.reply_to_message&.from_this_bot? && messages.include?(message.reply_to_message)
          result[:reply_to] = message.reply_to_message.api_id
        end

        # avoids ':' prefix on every key in the resulting YAML
        # https://stackoverflow.com/a/53093339
        result.deep_stringify_keys
      end.to_yaml({ line_width: -1 }) # Don't wrap long lines
    end

    private

    def llm_summarize(db_messages, summary_type)
      system_prompt = @style.blank? ? LLMTools.prompt_for_mode(summary_type) : custom_style_system_prompt
      user_prompt = SummarizeChatJob.messages_to_yaml(db_messages).strip

      output = LLMTools.run_chat_completion(system_prompt:, user_prompt:)

      raise FuckyWuckies::SummarizeJobFailure.new, 'Blank output' if output.blank?

      output
    rescue FuckyWuckies::SummarizeJobFailure,
           Faraday::UnprocessableEntityError => e
      # Prompt most likely too long, raise SummarizeJobError to retry with fewer messages
      raise FuckyWuckies::SummarizeJobError.new(
        severity: Logger::Severity::WARN
      ), 'Error: summarization failed -- prompt probably too long: ' \
         "chat api_id=#{@db_chat.id} title=#{@db_chat.title}", cause: e
    rescue Faraday::Error => e
      raise FuckyWuckies::SummarizeJobFailure.new(
        severity: Logger::Severity::ERROR,
        db_chat: @db_chat,
        frontend_message: 'API error! Try again later :(',
        sticker: :dead
      ), 'LLM API error: ' \
         "chat api_id=#{@db_chat.id} title=#{@db_chat.title}", cause: e
    end

    def custom_style_system_prompt
      <<~PROMPT.strip
        SUMMARY_STYLE=#{@style}
        Summarize YAML-formatted group chat messages in the specified SUMMARY_STYLE.
        Only provide the summary text to send in response message: no YAML, no formatting, no preface.
      PROMPT
    end

    def send_output_message(text)
      Telegram.bot.send_message(
        chat_id: @db_chat.api_id,
        protect_content: true,
        text:
      )
      TelegramTools.store_bot_output(@db_chat, text)
    end

    def handle_error(error)
      # Delete any running ChatSummary
      @db_chat.chat_summaries.where(status: 'running').destroy_all

      # Respond in chat with error message
      TelegramTools.send_error_message(error, @db_chat.api_id)
    end
  end
end
