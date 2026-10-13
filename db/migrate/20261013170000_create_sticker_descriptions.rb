# frozen_string_literal: true

class CreateStickerDescriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :sticker_descriptions do |t|
      t.string :file_unique_id, null: false, index: { unique: true }
      t.string :description, null: false
      t.timestamps
    end

    add_column :messages, :sticker_file_unique_id, :string

    change_column_comment :messages, :attachment_type,
                          from: '0=animation 1=audio 2=document 3=photo 4=video 5=voice',
                          to: '0=animation 1=audio 2=document 3=photo 4=video 5=voice 6=sticker'
  end
end
