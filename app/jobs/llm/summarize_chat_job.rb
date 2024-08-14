# frozen_string_literal: true

module LLM
  class SummarizeChatJob < ActiveJob::Base
    retry_on FuckyWuckies::SummarizeJobError
    rescue_from FuckyWuckies::SummarizeJobFailure, with: :handle_error

    def perform(db_summary)
      db_chat = db_summary.chat

      if executions > 4
        raise FuckyWuckies::SummarizeJobFailure.new(
          severity: Logger::Severity::ERROR,
          db_chat:,
          frontend_message: 'Processing failed, sowwy :(',
          sticker: :dead
        ), "All summarization attempts failed\n" \
           "chat api_id=#{db_chat.id} title=#{db_chat.title}"
      end

      messages_to_summarize = db_chat.messages_since_last_summary(db_summary.summary_type)

      # Each retry, since input didn't fit in LLM context, discard oldest 25% of messages
      if executions > 1
        reduced_count = (messages_to_summarize.size * (1 - ((executions - 1) / 4.0))).floor
        messages_to_summarize = messages_to_summarize.last(reduced_count)
      end

      result_text = llm_summarize(messages_to_summarize, db_chat, db_summary.summary_type)

      response_message = send_output_message(db_chat, result_text)

      db_summary.update!(
        text: result_text,
        status: 'complete',
        summary_message_api_id: response_message['message_id']
      )
    end

    private

    def llm_summarize(messages, db_chat, summary_type)
      client = OpenAI::Client.new

      yaml_messages = LLMTools.messages_to_yaml(messages)

      messages = [
        { role: 'system', content: LLMTools.prompt_for_style(summary_type) },
        { role: 'user', content: yaml_messages }
      ]

      result = StringIO.new
      client.chat(parameters: {
                    model: 'meta-llama/Meta-Llama-3-70B-Instruct',
                    max_tokens: 512,
                    temperature: 0.7,
                    messages:,
                    stream: proc do |chunk, _bytesize|
                              result << chunk.dig('choices', 0, 'delta', 'content')
                            end
                  })

      result.string
    rescue Faraday::UnprocessableEntityError => e
      # Prompt most likely too long, raise SummarizeJobError to retry with fewer messages
      raise FuckyWuckies::SummarizeJobError.new(
        severity: Logger::Severity::INFO
      ), "Error: summarization failed -- prompt probably too long\n" \
         "chat api_id=#{db_chat.id} title=#{db_chat.title}\n#{e}"
    rescue Faraday::Error => e
      raise FuckyWuckies::SummarizeJobFailure.new(
        severity: Logger::Severity::ERROR,
        db_chat:,
        frontend_message: 'API error! Try again later :(',
        sticker: :dead
      ), 'LLM API error: ' \
         "chat api_id=#{db_chat.id} title=#{db_chat.title}\n#{e}"
    end

    def send_output_message(db_chat, text)
      Telegram.bot.send_message(
        chat_id: db_chat.api_id,
        protect_content: true,
        text:
      )['result']
    end

    def handle_error(error)
      db_chat = error.db_chat
      raise error if db_chat.blank?

      # Delete any running ChatSummary
      db_chat.chat_summaries.where(status: 'running').destroy_all

      # Respond in chat with error message
      TelegramTools.send_error_message(error, db_chat.api_id)
    end
  end
end
