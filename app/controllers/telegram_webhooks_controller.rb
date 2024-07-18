# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  # Auto typecast to types from telegram-bot-types gem
  include Telegram::Bot::UpdatesController::TypedUpdate

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
    # logger.debug(message.to_yaml)
    store_message(message)

    # reply_with :message, text: message
  end

  ### Handle incoming edited messages
  def edited_message(message)
    store_edited_message(message)
  end

  private

  def store_message(message)
    return if message.from.is_bot

    chat = create_or_update_chat(message)
    user = create_or_update_user(message)
    chat_user = create_or_update_chat_user(chat, user, message)
    create_or_update_message(chat_user, message)
  end

  def store_edited_message(message)
    chat = create_or_update_chat(message)
    user = create_or_update_user(message)
    chat_user = create_or_update_chat_user(chat, user, message)
    create_or_update_message(chat_user, message)
  end

  def create_or_update_user(message)
    user = User.find_or_initialize_by(api_id: message.from.id)
    user.username = message.from.username
    user.first_name = message.from.first_name
    user.save!
    user
  end

  def create_or_update_chat(message)
    chat = Chat.find_or_initialize_by(api_id: message.chat.id)
    chat.title = message.chat.title
    chat.type = message.chat.type.to_sym
    chat.save!
    chat
  end

  def create_or_update_chat_user(chat, user, _message)
    ChatUser.create_or_update_by!(chat:, user:)
  end

  def create_or_update_message(chat_user, message)
    db_message = chat_user.messages.find_or_initialize_by(api_id: message.message_id)
    db_message.date = Time.utc.at(message.date).to_datetime
    db_message.text = message.text
    db_message.save!
    db_message
  end
end
