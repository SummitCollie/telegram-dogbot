# frozen_string_literal: true

require 'logger'

class TelegramTools
  def self.send_error_message(error, chat_api_id)
    logger.log(error.severity, error.message)
    Telegram.bot.send_sticker(chat_id: chat_api_id, sticker: TG_🐺♋🖼️_STICKERS_🌶️🍆💦[error.sticker]) if error.sticker
    Telegram.bot.send_message(chat_id: chat_api_id, text: error.frontend_message) if error.frontend_message
  end

  def self.link_to_message(chat_api_id, message_api_id)
    # https://core.telegram.org/api/links#message-links
    "https://t.me/c/#{chat_api_id}>/#{message_api_id}"
  end

  class << self
    def logger
      @logger ||= Logger.new(Rails.env.test? ? '/dev/null' : $stderr)
    end
  end
end
