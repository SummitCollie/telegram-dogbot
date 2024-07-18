# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      # Only unique within a given chat
      t.integer :api_id

      t.belongs_to :chat_user, null: false, foreign_key: true, index: true
      t.datetime :date
      t.string :text

      t.timestamps
    end
  end
end
