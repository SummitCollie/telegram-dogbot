# frozen_string_literal: true

module CloudflareAi
  class SummarizeChatJob < ActiveJob::Base
    retry_on FuckyWuckies::SummarizeJobError
    discard_on FuckyWuckies::SummarizeJobFailure

    def perform(db_summary)
      db_chat = db_summary.chat

      if executions > 4
        db_summary.destroy!

        raise FuckyWuckies::SummarizeJobFailure.new(
          severity: Logger::Severity::ERROR,
          frontend_message: 'Processing failed, sowwy :(',
          sticker: :dead
        ), "All summarization attempts failed\n" \
           "chat api_id=#{db_chat.id} title=#{db_chat.title}"
      end

      messages_to_summarize = db_chat.messages_since_last_summary(db_summary.summary_type)

      # Each retry, assuming last try failed because input didn't fit in LLM context,
      # discard oldest 25% of messages
      if executions > 1
        reduced_count = (messages_to_summarize.size * (1 - ((executions - 1) / 4.0))).floor
        messages_to_summarize = messages_to_summarize.last(reduced_count)
      end

      result_text = cloudflare_summarize(messages_to_summarize, db_summary.summary_type)

      # TODO: send message to chat with result
      # and remember to set protected flag to true!
      # response_message = send_message...

      db_summary.update!(
        text: result_text,
        status: :complete
        # summary_message_api_id: response_message.message_id
      )
    end

    private

    def cloudflare_summarize(messages, summary_type)
      Cloudflare::AI.logger.level = :info
      Cloudflare::AI.logger = Logger.new($stdout)

      client = Cloudflare::AI::Client.new(
        account_id: Rails.application.credentials.cloudflare.account_id,
        api_token: Rails.application.credentials.cloudflare.api_token
      )

      yaml_messages = LLMTools.messages_to_yaml(messages)

      messages = [
        Cloudflare::AI::Message.new(role: 'system', content: LLMTools.prompt_for_style(summary_type)),
        Cloudflare::AI::Message.new(role: 'user', content: yaml_messages)
      ]

      result = ''
      client.chat(messages:, model_name: '@cf/meta/llama-3-8b-instruct-awq', max_tokens: 512) do |data|
        if data == '[DONE]'
          # If prompt exceeds model context size, Cloudflare API returns success=true with empty text.
          # If this error gets triggered, that's probably the issue, so upon encountering this error
          # this job will retry a few times with a progressively smaller number of messages.
          if result.empty?
            raise FuckyWuckies::SummarizeJobError.new(
              severity: Logger::Severity::INFO
            ), "Error: summarization failed -- prompt probably too long\n" \
               "chat api_id=#{chat.id} title=#{chat.title}"
          end
        else
          result += JSON.parse(data)['response']
        end
      end

      result
    end
  end
end
