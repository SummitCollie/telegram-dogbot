# frozen_string_literal: true

require 'logger'

class TelegramTools
  # Bot messages longer than this are collapsed (see #collapse_if_long)
  COLLAPSE_MAX_LINES = 5
  COLLAPSE_MAX_CHARS = 500

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
        allowed_updates: %w[message edited_message my_chat_member callback_query]
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

    # Long messages are sent in a collapsed blockquote (unless send_params has its own parse_mode),
    # so they don't flood the chat
    def collapse_if_long(text, send_params)
      long = text.lines.size > COLLAPSE_MAX_LINES || text.length > COLLAPSE_MAX_CHARS
      return { text: } if !long || send_params.key?(:parse_mode)

      { text: "<blockquote expandable>#{ERB::Util.html_escape(text)}</blockquote>", parse_mode: 'HTML' }
    end

    # Returns the response, or nil (after deleting the message) if editing fails.
    # Bots' edits don't show as "edited" in Telegram, and don't notify anyone.
    def edit_into_message(db_chat, message_id, text, send_params)
      Telegram.bot.edit_message_text(
        chat_id: db_chat.api_id, message_id:, reply_markup: { inline_keyboard: [] },
        **collapse_if_long(text, send_params), **send_params.slice(:parse_mode)
      )
    rescue Telegram::Bot::Error => e
      logger.warn("Couldn't edit message #{message_id}, sending a new one instead: #{e.message}")
      begin
        Telegram.bot.delete_message(chat_id: db_chat.api_id, message_id:)
      rescue Telegram::Bot::Error
        nil # probably already deleted
      end
      nil
    end

    # Sends a message to the chat and saves a DB record of it, to be used in some LLM prompts.
    # Always sent synchronously (even if bot client is in async mode) to learn the sent message's api_id.
    # - reply_to: DB Message this one is stored as replying to. To also show it as a reply
    #   in Telegram, pass `reply_parameters:` (in send_params).
    # Returns the stored Message.
    # - replace_message_id: api_id of a message of this bot to edit into this one instead (e.g. a progress
    #   message, see LLMProgress), keeping its position. Its buttons are removed. Sent as new message if that fails.
    def send_bot_message(db_chat, text, reply_to: nil, replace_message_id: nil, **send_params)
      response = Telegram.bot.async(false) do
        (replace_message_id && edit_into_message(db_chat, replace_message_id, text, send_params)) ||
          Telegram.bot.send_message(chat_id: db_chat.api_id, **collapse_if_long(text, send_params), **send_params)
      end
      sent = response['result'] if response.is_a?(Hash)

      bot_user = User.find_or_initialize_by(is_this_bot: true)
      bot_chatuser = ChatUser.find_or_initialize_by(chat: db_chat, user: bot_user)

      Message.create!(
        chat_user: bot_chatuser,
        api_id: sent&.dig('message_id'),
        reply_to_message_id: reply_to&.id,
        date: sent&.dig('date') ? Time.zone.at(sent['date']) : Time.current,
        text:
      )
    end
  end
end
