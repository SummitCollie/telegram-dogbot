# frozen_string_literal: true

class CreateChats < ActiveRecord::Migration[7.1]
  def change
    create_table :chats do |t|
      t.bigint :api_id, null: false, index: true
      t.integer :type, null: false
      t.string :title

      t.timestamps
    end
  end
end
