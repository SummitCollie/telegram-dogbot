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
      # rubocop:enable Style/IfUnlessModifier, Style/GuardClause
    end

    private

    def from_bot?
      from.is_bot
    end

    def empty_text?(message)
      message.text.nil?
    end
  end
end
