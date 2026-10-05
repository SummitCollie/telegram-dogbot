# frozen_string_literal: true

module LLM
  class SummarizeChatJob < ApplicationJob
    retry_on FuckyWuckies::SummarizeJobError
    rescue_from FuckyWuckies::SummarizeJobFailure, with: :handle_error

    # Cancelled from progress message: delete the running ChatSummary so another can be started
    discard_on(LLMProgress::Cancelled) do |job, error|
      job.arguments.first.destroy
      TelegramTools.logger.info(error.message)
    end

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

      label = summary.summary_type.to_s == 'vibe_check' ? 'a vibe check' : 'a summary'
      result_text = LLMProgress.track(@db_chat, label:) do |progress|
        llm_summarize(messages_to_summarize, summary.summary_type, progress)
      end

      send_output_message(result_text)
      summary.update!(text: result_text, status: 'complete')
    end

    def self.chat_log(messages)
      messages.map do |message|
        reply_to = message.reply_to_message
        LLMTools.chat_log_line(id: message.api_id, user: message.user.first_name, text: message.text,
                               attachment: message.attachment_type,
                               reply_to: ("##{reply_to.api_id}" if messages.include?(reply_to)))
      end.join("\n")
    end

    private

    def llm_summarize(db_messages, summary_type, progress)
      system_prompt = @style.blank? ? LLMTools.prompt_for_mode(summary_type) : custom_style_system_prompt
      user_prompt = SummarizeChatJob.chat_log(db_messages)

      TelegramTools.logger.debug("\n##### Summarize chat:\n" \
                                 "### System prompt:\n#{system_prompt}\n" \
                                 "### User prompt:\n#{user_prompt}")

      output = LLMTools.run_chat_completion(system_prompt:, user_prompt:, progress:)

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
        Summarize the group chat messages in the specified SUMMARY_STYLE.
        Only provide the summary text to send in response message: no formatting, no preface.
      PROMPT
    end

    def send_output_message(text)
      TelegramTools.send_bot_message(@db_chat, text, protect_content: true)
    end

    def handle_error(error)
      # Delete any running ChatSummary
      @db_chat.chat_summaries.where(status: 'running').destroy_all

      # Respond in chat with error message
      TelegramTools.send_error_message(error, @db_chat.api_id)
    end
  end
end
