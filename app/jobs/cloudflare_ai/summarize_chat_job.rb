# frozen_string_literal: true

module CloudflareAi
  class SummarizeChatJob < ApplicationJob
    retry_on FuckyWuckies::SummarizeJobError
    discard_on FuckyWuckies::SummarizeJobFailure

    def perform(*args)
      # db_summary = ChatSummary.create!(
      #   chat:,
      #   type:,
      #   status: :running,
      # )

      messages_to_summarize = db_chat.messages_since_last_summary
      yaml_messages = transform_messages_to_yaml(messages_to_summarize)
      result_text = cloudflare_summarize(yaml_messages)

      # `executions` attribute is retry count
      # TODO: each retry, if input doesn't fit in LLM context, discard oldest 25% of messages

      # db_summary.update!(
      #   text: result_text,
      #   first_message: = whatever first message ends up succeeding
      # )
    end

    private

    def summarize_prompt
      return @summarize_prompt if @summarize_prompt

      example_summary = File.read('data/example-summary-for-prompt.txt')
      @summarize_prompt = <<~TEXT
        You are a helpful chat bot who summarizes group chat messages.
        Your goal is to concisely highlight each chat member's stories and the general subjects discussed in the chat.
        Do not provide opinions or suggestions, simply extract and present the key points and main themes in a bulleted list.
        You will receive the messages in YAML format, but do not mention this in the summary.
        Do not add any notes or preface the summary with any message such as "This is a summary of the chat:"
        Your response should ONLY contain the bullet points of the summary.

        ---EXAMPLE SUMMARY---
        #{example_summary}
      TEXT
    end

    def transform_messages_to_yaml(messages)
      messages.map do |message|
        result = {
          id: message.id,
          user: message.user.first_name,
          text: message.text
        }

        result.reply_to = message.reply_to_message if message.reply_to_message.present?
        result.attachment = message.attachment_type.to_s if message.attachment_type.present?

        result
      end.to_yaml
    end

    def cloudflare_summarize(yaml_messages)
      Cloudflare::AI.logger.level = :info
      Cloudflare::AI.logger = Logger.new($stdout)

      client = Cloudflare::AI::Client.new(
        account_id: Rails.application.credentials.cloudflare.account_id,
        api_token: Rails.application.credentials.cloudflare.api_token
      )

      messages = [
        Cloudflare::AI::Message.new(role: 'system', content: summarize_prompt),
        Cloudflare::AI::Message.new(role: 'user', content: yaml_messages)
      ]

      result = ''
      client.chat(messages:, model_name: '@cf/meta/llama-3-8b-instruct-awq', max_tokens: 512) do |data|
        if data == '[DONE]'
          raise StandardError 'Error: summarization failed' if result.empty?
        else
          result += JSON.parse(data)['response']
        end
      end

      result
    end
  end
end
