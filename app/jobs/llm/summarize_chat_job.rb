# frozen_string_literal: true

module LLM
  class SummarizeChatJob < ApplicationJob
    retry_on FuckyWuckies::SummarizeJobError
    rescue_from FuckyWuckies::SummarizeJobFailure, with: :handle_error

    def perform(db_summary)
      @db_chat = db_summary.chat

      if executions > 4
        raise FuckyWuckies::SummarizeJobFailure.new(
          severity: Logger::Severity::ERROR,
          db_chat: @db_chat,
          frontend_message: 'Processing failed, sowwy :(',
          sticker: :dead
        ), "All summarization attempts failed: " \
           "chat api_id=#{@db_chat.id} title=#{@db_chat.title}"
      end

      messages_to_summarize = @db_chat.messages_since_last_summary(db_summary.summary_type)

      # Each retry, since input didn't fit in LLM context, discard oldest 25% of messages
      if executions > 1
        reduced_count = (messages_to_summarize.size * (1 - ((executions - 1) / 4.0))).floor
        messages_to_summarize = messages_to_summarize.last(reduced_count)
      end

      result_text = llm_summarize(messages_to_summarize, db_summary.summary_type)

      send_output_message(result_text)
      db_summary.update!(text: result_text, status: 'complete')
    end

    private

    def llm_summarize(db_messages, summary_type)
      system_prompt = LLMTools.prompt_for_style(summary_type)
      user_prompt = LLMTools.messages_to_yaml(db_messages)

      output = LLMTools.run_chat_completion(system_prompt:, user_prompt:)

      raise FuckyWuckies::SummarizeJobFailure.new, 'Blank output' if output.blank?

      output
    rescue FuckyWuckies::SummarizeJobFailure,
           Faraday::UnprocessableEntityError => e
      # Prompt most likely too long, raise SummarizeJobError to retry with fewer messages
      raise FuckyWuckies::SummarizeJobError.new(
        severity: Logger::Severity::WARN
      ), "Error: summarization failed -- prompt probably too long: " \
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
