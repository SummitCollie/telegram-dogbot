# frozen_string_literal: true

require 'logger'

class TelegramTools
  class << self
    def logger
      @logger ||= Logger.new(
        Rails.env.test? ? File::NULL : $stderr,
        level: ENV.fetch('RAILS_LOG_LEVEL', Rails.env.production? ? 'info' : 'debug')
      )
    end

    def set_webhook
      routes = Rails.application.routes.url_helpers
      url = routes.send('telegram_webhook_url')
      logger.info('Setting DogBot webhook...')

      Telegram.bot.set_webhook(
        url:,
        drop_pending_updates: false,
        secret_token: Rails.application.credentials.telegram_secret_token,
        allowed_updates: %w[message edited_message my_chat_member]
      )
    end

    # rubocop:disable Style/GuardClause
    def send_error_message(error, chat_api_id)
      logger.log(error.severity, error.message)

      if error.sticker
        Telegram.bot.send_sticker(
          chat_id: chat_api_id,
          sticker: TG_🐺♋🖼️_STICKERS_🌶️🍆💦[error.sticker]
        )
      end

      if error.frontend_message
        Telegram.bot.send_message(
          chat_id: chat_api_id,
          text: error.frontend_message,
          parse_mode: error.parse_mode
        )
      end
    end
    # rubocop:enable Style/GuardClause

    # Returns the thing from the message that we want to save in the DB, or nil if missing.
    # - Sticker messages have an emoji we can log as message text
    # - Messages with media attached (photo, video, ...) use `caption` instead of `text`
    def extract_message_text(api_message)
      if (emoji = api_message.try(:sticker).try(:emoji).presence)
        # Save textual description of emoji because it helps LLM understand it
        return "#{emoji} (#{Unicode::Name.of(emoji).downcase})"
      end

      api_message.try(:text).presence || api_message.try(:caption).presence
    end

    def attachment_type(api_message)
      Message.attachment_types.keys.find { |type| !!api_message[type] }
    end

    def strip_bot_command(command_name, str)
      str.gsub(%r{^/#{command_name}(\S?)+}, '').strip
    end

    def serialize_api_message(message)
      serialized = {
        message_id: message.message_id,
        text: TelegramTools.extract_message_text(message),
        date: message.date,
        from: {
          first_name: message.from.first_name,
          username: message.from.username
        }
      }

      if message.reply_to_message.present?
        serialized[:reply_to_message] = {
          message_id: message.reply_to_message.message_id,
          text: message.reply_to_message.text,
          date: message.reply_to_message.date,
          from: {
            first_name: message.reply_to_message.from.first_name,
            username: message.reply_to_message.from.username
          }
        }
      end

      serialized.to_json
    end

    def deserialize_api_message(json)
      JSON.parse(json, object_class: OpenStruct)
    end

    # Save a DB record of this bot's outgoing messages, to be used in some LLM prompts
    def store_bot_output(db_chat, text, reply_to: nil)
      bot_user = User.find_or_initialize_by(is_this_bot: true)
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
