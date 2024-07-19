# frozen_string_literal: true

class CreateChatUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :chat_users do |t|
      t.belongs_to :chat, null: false, foreign_key: true
      t.belongs_to :user, null: false, foreign_key: true
      t.integer :num_chatuser_messages, default: 0,
                                        comment: 'All-time count of messages sent by this ChatUser'
      t.integer :num_stored_messages, default: 0,
                                      comment: 'Current number of messages from this ChatUser stored in the DB'

      t.timestamps
    end

    add_index :chat_users, %i[chat_id user_id], unique: true
  end
end
