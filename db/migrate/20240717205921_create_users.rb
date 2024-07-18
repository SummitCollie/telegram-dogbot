# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.bigint :api_id, null: false, unique: true
      t.string :first_name
      t.string :username

      t.timestamps
    end
  end
end
