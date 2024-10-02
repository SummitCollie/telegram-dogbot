# frozen_string_literal: true

require 'logger'

class TelegramTools
  class << self
    def logger
      @logger ||= Logger.new(Rails.env.test? ? '/dev/null' : $stderr)
    end

    def send_error_message(error, chat_api_id)
      logger.log(error.severity, error.message)
      Telegram.bot.send_sticker(chat_id: chat_api_id, sticker: TG_🐺♋🖼️_STICKERS_🌶️🍆💦[error.sticker]) if error.sticker
      Telegram.bot.send_message(chat_id: chat_api_id, text: error.frontend_message) if error.frontend_message
    end

    # Returns the thing from the message that we want to save in the DB, or nil if missing.
    # - Sticker messages have an emoji we can log as message text
    # - Messages with media attached (photo, video, ...) use `caption` instead of `text`
    def extract_message_text(message)
      message.text.presence || message.sticker&.emoji.presence || message.caption.presence
    end
  end
end
