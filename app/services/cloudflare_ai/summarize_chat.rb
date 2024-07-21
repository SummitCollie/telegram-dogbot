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
        prompt: 'Hello, my name is ',
        model_name: "@cf/meta/llama-3-8b-instruct"
      )
    end
  end
end
