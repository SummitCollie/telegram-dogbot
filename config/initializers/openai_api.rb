# frozen_string_literal: true

OpenAI.configure do |config|
  config.log_errors = Rails.env.development?
  config.uri_base = Rails.application.credentials.openai.uri_base
  config.access_token = Rails.application.credentials.openai.access_token
  config.request_timeout = 240
end
