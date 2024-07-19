# frozen_string_literal: true

class CreateChats < ActiveRecord::Migration[7.1]
  def change
    create_table :chats do |t|
      t.bigint :api_id, null: false, index: true
      t.integer :api_type, null: false, comment: '0=private 1=group 2=supergroup 3=channel'
      t.datetime :last_summary_started
      t.datetime :last_nice_summary_started
      t.string :title

      t.timestamps
    end
  end
end
