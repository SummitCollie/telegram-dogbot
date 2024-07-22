# frozen_string_literal: true

require 'active_interaction'

module CloudflareAi
  class SummarizeChat < ActiveInteraction::Base
    object :db_chat, class: Chat

    def execute
      messages_to_summarize = db_chat.messages_since_last_summary
      yaml_messages = transform_messages_to_yaml(messages_to_summarize)
      cloudflare_summarize(yaml_messages) do |result|
        # TODO: something
      end
    end
  end

  private

  def summarization_prompt
    return @summarization_prompt if @summarization_prompt

    example_chatlogs = File.read('data/example-chat-for-prompt.txt')
    example_summary = File.read('data/example-summary-for-prompt.txt')

    @summarization_prompt = 'You are a summarization bot tasked with summarizing the chat log provided below. ' \
                            "Your goal is to concisely highlight each chat member's stories and the general " \
                            'subjects discussed in the chat. Do not provide opinions or suggestions. ' \
                            'Simply extract and present the key points and main themes.' \
                            'Do not add any notes or preface the summary with any message such as ' \
                            '"This is a summary of the chat:". ' \
                            "Your response should ONLY contain the bullet points of the summary.\n\n" \
                            "---EXAMPLE CHAT---\n#{example_chatlogs}\n\n" \
                            "---EXAMPLE RESPONSE---\n#{example_summary}"
  end

  def transform_messages_to_yaml(messages)
    messages
  end

  def cloudflare_summarize(yaml_messages)
    Cloudflare::AI.logger.level = :info
    Cloudflare::AI.logger = Logger.new($stdout)

    client = Cloudflare::AI::Client.new(
      account_id: Rails.application.credentials.cloudflare.account_id,
      api_token: Rails.application.credentials.cloudflare.api_token
    )

    messages = [
      Cloudflare::AI::Message.new(role: 'system', content: summarization_prompt),
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
    nil
  end
end
