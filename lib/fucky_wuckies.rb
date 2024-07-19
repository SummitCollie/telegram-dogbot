# frozen_string_literal: true

module FuckyWuckies
  class BaseError < StandardError
    attr_accessor :severity, :frontend_message, :sticker

    def initialize(severity: Logger::DEBUG, frontend_message: nil, sticker: nil)
      super

      @severity = severity
      @frontend_message = frontend_message
      @sticker = sticker
    end
  end

  class AuthorizationError < BaseError; end
  class MessageFilterError < BaseError; end
  class NotAGroupChatError < BaseError; end
  class ChatNotWhitelistedError < BaseError; end
end
