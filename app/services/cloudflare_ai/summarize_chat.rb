# frozen_string_literal: true

require 'active_interaction'

module CloudflareAi
  class SummarizeChat < ActiveInteraction::Base
    object :db_chat, class: Chat

    def execute
      Cloudflare::AI.logger.level = :debug
      Cloudflare::AI.logger = Logger.new($stdout)

      client = Cloudflare::AI::Client.new(
        account_id: Rails.application.credentials.cloudflare.account_id,
        api_token: Rails.application.credentials.cloudflare.api_token
      )

      fake_chatlogs = File.read('/home/user/Desktop/example-chat-for-prompt.txt')
      fake_summary = File.read('/home/user/Desktop/example-summary-for-prompt.txt')

      fake_chatlogs_input = File.read('/home/user/Desktop/fake-chat-2.txt')
      fake_chatlogs_long = File.read('/home/user/Desktop/fake_chatlog_4386_tokens.txt')
      fake_chat_short = File.read('/home/user/Desktop/fake-chat.txt')

      messages = [
        Cloudflare::AI::Message.new(
          role: "system",
          content: "You are a summarization bot tasked with summarizing the chat log provided below. " \
                    "Your goal is to concisely highlight each chat member's stories and the general " \
                    "subjects discussed in the chat. Do not provide opinions or suggestions. " \
                    "Simply extract and present the key points and main themes.\n\n" \
                    "---EXAMPLE CHAT---\n#{fake_chatlogs}\n\n" \
                    "---EXAMPLE RESPONSE---\n#{fake_summary}"),
        # Cloudflare::AI::Message.new(role: "user", content: fake_chatlogs),
        # Cloudflare::AI::Message.new(role: "assistant", content: fake_summary),
        Cloudflare::AI::Message.new(role: "user", content: fake_chat_short)
      ]

      result = ''
      client.chat(messages: messages, model_name: "@cf/meta/llama-3-8b-instruct", max_tokens: 512) do |data|
        # {"response":"Here","p":"abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklm"}
        # {"response":" is","p":"abcdefghijklmnopqr"}
        # {"response":" a","p":"abcdefghijk"}
        # {"response":" summary","p":"abcdefghijklmnopqrstuvwxyz012"}
        # {"response":" of"}
        # {"response":" the","p":"abcdefg"}
        # {"response":" chat","p":"abcdefghijklmnopqrstuvwxyz0123456789a"}

        if data == '[DONE]'
          puts result
        else
          result += JSON.parse(data)['response']
        end
      end

      # result = client.complete(
      #   prompt: 'Hello, I am dog',
      #   model_name: "@cf/meta/llama-3-8b-instruct",
      #   max_tokens: 512
      # )
      #<Cloudflare::AI::Results::TextGeneration:0x00007fe3bb530e70
      # @result_data=
      # {"result"=>{"response"=>"It's so nice to meet you, dog! My name is Ada, and I'm your friendly AI assistant. I'm here to help you with any questions or topics you'd like to discuss. How's your day going so far?"},
      #   "success"=>true,
      #   "errors"=>[],
      #   "messages"=>[]}>
  end
end
