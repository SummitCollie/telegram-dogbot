# frozen_string_literal: true

class TelegramWebhooksController
  module ReplyHelpers
    module_function

    def bot_mentioned?
      TelegramTools.extract_message_text(payload).downcase.include?("@#{
        Rails.application.credentials.telegram.bot.username.downcase
      }")
    end

    def replied_to_bot?
      replied_to_message = payload&.reply_to_message
      return false if replied_to_message.blank?

      replied_to_message.from&.username == Rails.application.credentials.telegram.bot.username
    end
  end
end
