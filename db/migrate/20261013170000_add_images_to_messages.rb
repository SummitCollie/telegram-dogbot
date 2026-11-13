# frozen_string_literal: true

class AddImagesToMessages < ActiveRecord::Migration[7.1]
  def change
    change_table :messages, bulk: true do |t|
      t.string :image_file_id, comment: 'Telegram file_id of a still image of the photo/sticker/GIF/video'
      t.integer :image_status, comment: '0=pending 1=described 2=failed (null: no image to describe)'
      t.text :image_description
      t.string :sticker_file_unique_id
      t.string :media_group_id, comment: 'Shared by photos sent together as an album'
    end

    change_column_comment :messages, :attachment_type,
                          from: '0=animation 1=audio 2=document 3=photo 4=video 5=voice',
                          to: '0=animation 1=audio 2=document 3=photo 4=video 5=voice 6=sticker'

    # Photos, for prompts to show self-hosted models with vision. Deleted along with their message.
    create_table :message_images do |t|
      t.references :message, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.binary :data, null: false
      t.timestamps
    end

    # Kept forever, unlike messages: stickers get reused long after the nightly purge
    create_table :sticker_descriptions do |t|
      t.string :file_unique_id, null: false, index: { unique: true }
      t.text :description, null: false
      t.timestamps
    end
  end
end
