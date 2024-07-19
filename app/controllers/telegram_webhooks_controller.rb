# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include StoreMessages
  include IncomingMessageFilter

  # Auto typecast to types from telegram-bot-types gem
  include Telegram::Bot::UpdatesController::TypedUpdate

  rescue_from Exceptions::ChatNotWhitelistedError, with: :handle_chat_not_whitelisted
  rescue_from Exceptions::MessageFilterError, with: :debug_log_filtered_messages

  mattr_reader :stickers, default: {
    hmm: 'CAACAgEAAxkBAAN7Zpnjiy4fEBQDljYzOMMDE13t63cAAhYDAAJ1DsgJD2dJhv6G8sY1BA'
  }

  ### Handle commands
  def summarize!(*); end

  def summarize_nicely!(*); end

  def stats!(*)
    # Messages from chat currently stored in DB
    # Total messages seen from chat (including deleted)
    # Message counts per user in a chat (only show top 5 users)
  end

  ### Handle unknown commands
  def action_missing(_action, *_args)
    return unless action_type == :command

    reply_with :message, text: 'Invalid command!'
  end

  ### Handle incoming message - https://core.telegram.org/bots/api#message
  def message(message)
    verify_should_store_message!(message)

    db_message = store_message(message)

    # reply_with :message, text: message
    reply_with :message, text: "Message ##{message.message_id} stored!" if db_message
  end

  ### Handle incoming edited message
  def edited_message(message)
    verify_should_store_message!(message)

    store_edited_message(message)
  end

  private

  def handle_chat_not_whitelisted
    bot.send_sticker(chat_id: chat.id, sticker: stickers[:hmm])
    respond_with :message,
                 text: "This chat isn't whitelisted (AI costs money)!\nContact Summit and maybe he'll allow it."
  end

  def debug_log_filtered_messages(error)
    logger.debug(error.message)
  end
end
