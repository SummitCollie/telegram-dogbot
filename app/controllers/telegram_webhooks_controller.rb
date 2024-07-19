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
    db_message = store_message(message)

    # reply_with :message, text: message
    reply_with :message, text: "Message ##{message.message_id} stored!" if db_message
  end

  ### Handle incoming edited message
  def edited_message(message)
    store_edited_message(message)
  end

  private

  ###
  ### Store messages & edits
  ###
  def store_message(message)
    if from.is_bot
      logger.debug("Not saving bot message, api_id=#{message.message_id}")
      return
    end
    if message.text.nil?
      logger.debug("Not saving message with no text: api_id=#{message.message_id}")
      return
    end

    db_chat = create_or_update_chat
    db_user = create_or_update_user
    db_chat_user = create_or_update_chat_user(db_chat, db_user)
    db_message = create_or_update_message(db_chat, db_chat_user, message)

    # rubocop:disable Rails::SkipsModelValidations
    ChatUser.increment_counter :num_chatuser_messages, db_chat_user.id
    # rubocop:enable Rails::SkipsModelValidations

    db_message
  end

  def store_edited_message(message)
    db_chat = create_or_update_chat
    db_user = create_or_update_user
    db_chat_user = create_or_update_chat_user(db_chat, db_user)
    create_or_update_message(db_chat, db_chat_user, message)
  end

  ###
  ### Create/update DB records
  ###
  def create_or_update_chat
    db_chat = Chat.find_or_initialize_by(api_id: chat.id)
    db_chat.title = chat.title
    db_chat.api_type = :"#{chat.type}_room"
    db_chat.save!
    db_chat
  end

  def create_or_update_user
    db_user = User.find_or_initialize_by(api_id: from.id)
    db_user.username = from.username
    db_user.first_name = from.first_name
    db_user.save!
    db_user
  end

  def create_or_update_chat_user(db_chat, db_user)
    db_chat_user = ChatUser.find_or_initialize_by(chat: db_chat, user: db_user)
    db_chat_user.save!
    db_chat_user
  end

  def create_or_update_message(db_chat, db_chat_user, message)
    db_message = db_chat_user.messages.find_or_initialize_by(api_id: message.message_id)
    db_message.reply_to_message_id = db_chat.messages.find_by(api_id: message.reply_to_message&.message_id)&.id
    db_message.date = Time.zone.at(message.date).to_datetime
    db_message.text = message.text
    db_message.save!
    db_message
  end
end
