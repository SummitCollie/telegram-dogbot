# frozen_string_literal: true

module FuckyWuckies
  class BaseError < StandardError
    attr_accessor :severity, :frontend_message, :parse_mode, :sticker, :db_chat

    def initialize(severity: Logger::Severity::DEBUG,
                   frontend_message: nil, parse_mode: nil,
                   sticker: nil, db_chat: nil)
      super
      @severity = severity
      @frontend_message = frontend_message
      @parse_mode = parse_mode
      @sticker = sticker
      @db_chat = db_chat
    end
  end

  class AuthorizationError < BaseError; end
  class MessageFilterError < BaseError; end
  class NotAGroupChatError < BaseError; end
  class ChatNotWhitelistedError < BaseError; end
  class MissingArgsError < BaseError; end
  class SummarizeJobError < BaseError; end
  class SummarizeJobFailure < BaseError; end
  class TranslateJobFailure < BaseError; end
  class ReplyJobFailure < BaseError; end
end
