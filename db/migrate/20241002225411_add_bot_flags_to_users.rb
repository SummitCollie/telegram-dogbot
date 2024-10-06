# frozen_string_literal: true

# rubocop:disable Rails/BulkChangeTable
class AddBotFlagsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :is_bot, :boolean, null: false, default: false
    add_column :users, :is_this_bot, :boolean, null: false, default: false
  end
end
# rubocop:enable Rails/BulkChangeTable
