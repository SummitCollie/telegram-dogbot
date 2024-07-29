# frozen_string_literal: true

class CreateChatSummaries < ActiveRecord::Migration[7.1]
  def change
    create_table :chat_summaries do |t|
      t.belongs_to :chat, null: false, foreign_key: true, index: true
      t.integer :status, null: false, default: 0, comment: '0=running 1=complete'
      t.integer :type, null: false, comment: '0=default 1=nice 2=vibe_check'
      t.integer :summary_message_api_id, comment: 'api_id of the message where the bot sent this summary output'
      t.string :text

      t.timestamps
    end

    add_index :chat_summaries, :created_at
  end
end
