# frozen_string_literal: true

# TODO: remove this when supported upstream
# Patch telegram-bot gem to filter text from messages in prod logs
# Adapted from comment on GitHub issue:
# https://github.com/telegram-bot-rb/telegram-bot/issues/239#issuecomment-2242341493
module HackyWackies
  module TelegramLogSubscriber
    FILTERED_PARAMS = %i[text].freeze

    def start_processing(event)
      info do
        payload = event.payload
        update = payload[:update].to_h
        update = sanitize_sensitive_data(update) unless Rails.env.local?
        "Processing by #{payload[:controller]}##{payload[:action]}\n  " \
          "Update: #{update.to_json}"
      end
    end

    private

    def sanitize_sensitive_data(update)
      parameter_filter.filter(update)
    end

    def parameter_filter
      @parameter_filter ||= ActiveSupport::ParameterFilter.new(FILTERED_PARAMS)
    end
  end
end

Rails.application.reloader.to_prepare do
  Telegram::Bot::UpdatesController::LogSubscriber.prepend(
    HackyWackies::TelegramLogSubscriber
  )
end
