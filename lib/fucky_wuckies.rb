# frozen_string_literal: true

module FuckyWuckies
  class BaseError < StandardError
    attr_accessor :severity, :frontend_message, :sticker, :db_chat

    def initialize(severity: Logger::Severity::DEBUG, frontend_message: nil, sticker: nil, db_chat: nil)
      super

      @severity = severity
      @frontend_message = frontend_message
      @sticker = sticker
      @db_chat = db_chat
    end
  end

  class AuthorizationError < BaseError; end
  class MessageFilterError < BaseError; end
  class NotAGroupChatError < BaseError; end
  class ChatNotWhitelistedError < BaseError; end
  class SummarizeJobError < BaseError; end
  class SummarizeJobFailure < BaseError; end
end
