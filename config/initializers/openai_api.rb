# frozen_string_literal: true

OpenAI.configure do |config|
  if Rails.env.test?
    config.log_errors = true
    config.uri_base = nil
    config.access_token = nil
  else
    config.log_errors = Rails.env.development?
    config.uri_base = Rails.application.credentials.openai.uri_base
    config.access_token = Rails.application.credentials.openai.access_token
    config.request_timeout = 240
  end
end
