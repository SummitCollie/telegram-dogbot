# frozen_string_literal: true

class TelegramWebhooksController
  module IncomingMessageFilter
    extend self

    def verify_should_store_message!(message)
      # rubocop:disable Style/IfUnlessModifier, Style/GuardClause
      if from_bot?
        raise Exceptions::MessageFilterError, "Not saving bot message: api_id=#{message.message_id}"
      end
      if empty_text?(message)
        raise Exceptions::MessageFilterError, "Not saving message with empty text: api_id=#{message.message_id}"
      end
      unless chat_in_whitelist?
        raise Exceptions::ChatNotWhitelistedError, "Chat not in whitelist: api_id=#{chat.id}"
      end
      # rubocop:enable Style/IfUnlessModifier, Style/GuardClause
    end

    private

    def from_bot?
      from.is_bot
    end

    def empty_text?(message)
      message.text.nil?
    end

    def chat_in_whitelist?
      Rails.application.credentials.chat_id_whitelist&.include?(chat.id)
    end
  end
end
