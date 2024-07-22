# frozen_string_literal: true

require 'active_interaction'

module CloudflareAi
  class SummarizeChat < ActiveInteraction::Base
    object :db_chat, class: Chat

    def execute
      client = Cloudflare::AI::Client.new(
        account_id: Rails.application.credentials.cloudflare.account_id,
        api_token: Rails.application.credentials.cloudflare.api_token
      )

      result = client.complete(
        prompt: 'Hello, I am dog',
        model_name: "@cf/meta/llama-3-8b-instruct",
        max_tokens: 512
      )

      #<Cloudflare::AI::Results::TextGeneration:0x00007fe3bb530e70
      # @result_data=
      # {"result"=>{"response"=>"It's so nice to meet you, dog! My name is Ada, and I'm your friendly AI assistant. I'm here to help you with any questions or topics you'd like to discuss. How's your day going so far?"},
      #   "success"=>true,
      #   "errors"=>[],
      #   "messages"=>[]}>
    end
  end
end
