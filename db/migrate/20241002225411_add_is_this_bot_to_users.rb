# frozen_string_literal: true

class AddIsThisBotToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :is_this_bot, :boolean, null: false, default: false
  end
end
