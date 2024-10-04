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
    def extract_message_text(api_message)
      api_message.text.presence || api_message.sticker&.emoji.presence || api_message.caption.presence
    end

    def attachment_type(api_message)
      Message.attachment_types.keys.find { |type| !!api_message[type] }
    end

    def serialize_api_message(message)
      {
        message_id: message.message_id,
        text: message.text,
        date: message.date,
        from: {
          first_name: message.from.first_name,
          username: message.from.username
        },
        reply_to_message: message.reply_to_message.present? && {
          message_id: message.reply_to_message.message_id,
          text: message.reply_to_message.text,
          date: message.reply_to_message.date,
          from: {
            first_name: message.reply_to_message.from.first_name,
            username: message.reply_to_message.from.username
          }
        }
      }.to_json
    end

    def deserialize_api_message(json)
      JSON.parse(json, object_class: OpenStruct)
    end

    # Save a DB record of this bot's outgoing messages, to be used in some LLM prompts
    def store_bot_output(db_chat, text, reply_to: nil)
      bot_user = User.find_or_initialize_by(api_id: -1, is_this_bot: true)
      bot_chatuser = ChatUser.find_or_initialize_by(chat: db_chat, user: bot_user)

      Message.create!(
        chat_user: bot_chatuser,
        reply_to_message_id: reply_to&.id,
        date: Time.current,
        text:
      )
    end
  end
end
