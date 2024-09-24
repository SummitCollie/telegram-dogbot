# frozen_string_literal: true

class TelegramWebhooksController
  module MessageStorage
    extend self

    ###
    ### Store messages & edits
    ###
    def store_message(message)
      db_chat = create_or_update_chat
      db_user = create_or_update_user
      db_chat_user = create_or_update_chat_user(db_chat, db_user)
      db_message = create_message(db_chat, db_chat_user, message)

      # rubocop:disable Rails::SkipsModelValidations
      ChatUser.increment_counter :num_chatuser_messages, db_chat_user.id
      # rubocop:enable Rails::SkipsModelValidations

      db_message
    end

    def store_edited_message(message)
      db_chat = create_or_update_chat
      db_user = create_or_update_user
      db_chat_user = create_or_update_chat_user(db_chat, db_user)

      update_message(db_chat, db_chat_user, message)
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

    # https://core.telegram.org/bots/api#message
    def create_message(db_chat, db_chat_user, message)
      db_message = db_chat_user.messages.build(api_id: message.message_id)

      Message.attachment_types.each_key do |attachment_type|
        db_message.attachment_type = attachment_type.to_sym if message[attachment_type]
      end

      db_message.date = Time.zone.at(message.date).to_datetime
      db_message.reply_to_message_id = db_chat.messages.find_by(api_id: message.reply_to_message&.message_id)&.id
      db_message.text = determine_message_text(db_message.attachment_type.present?, message)

      db_message.save!
      db_message
    end

    def update_message(db_chat, db_chat_user, message)
      db_message = db_chat_user.messages.find_by(api_id: message.message_id)
      return unless db_message

      Message.attachment_types.each_key do |attachment_type|
        db_message.attachment_type = attachment_type.to_sym if message[attachment_type]
      end

      db_message.reply_to_message_id = db_chat.messages.find_by(api_id: message.reply_to_message&.message_id)&.id
      db_message.text = determine_message_text(db_message.attachment_type.present?, message)

      db_message.save!
      db_message
    end

    def determine_message_text(has_attached_media, message)
      if message.sticker&.emoji
        message.sticker&.emoji
      else
        has_attached_media ? message.caption : message.text
      end
    end
  end
end
