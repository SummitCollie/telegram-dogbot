# frozen_string_literal: true

class CreateChats < ActiveRecord::Migration[7.1]
  def change
    create_table :chats do |t|
      t.bigint :api_id, unique: true
      t.string :title
      t.integer :type
      t.integer :num_total_messages, default: 0

      t.timestamps
    end
  end
end
