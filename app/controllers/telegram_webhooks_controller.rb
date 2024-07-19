# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include StoreMessages
  include IncomingMessageFilter

  # Auto typecast to types from telegram-bot-types gem
  include Telegram::Bot::UpdatesController::TypedUpdate

  rescue_from Exceptions::MessageFilterError, with: :debug_log_filtered_messages

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

  def debug_log_filtered_messages(error)
    logger.debug(error.message)
  end
end
