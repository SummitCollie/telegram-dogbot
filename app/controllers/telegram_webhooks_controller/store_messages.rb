# frozen_string_literal: true

class TelegramWebhooksController
  module StoreMessages
    extend self

    ###
    ### Store messages & edits
    ###
    def store_message(message)
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

    private

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
end
