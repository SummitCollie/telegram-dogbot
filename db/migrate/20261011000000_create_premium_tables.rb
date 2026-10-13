# frozen_string_literal: true

class CreatePremiumTables < ActiveRecord::Migration[7.1]
  def change
    # Per-user settings for DMs with the bot (premium)
    create_table :dm_settings do |t|
      t.belongs_to :user, null: false, foreign_key: true, index: { unique: true }

      t.datetime :consented_at, comment: 'When the user confirmed being 18+ & agreed to the terms/privacy notice'
      t.integer :consented_terms_version, comment: 'Premium::TERMS_VERSION they agreed to'

      t.string :bot_name, comment: "Bot's name in this user's DMs"
      t.text :persona, comment: "Bot's personality in this user's DMs"
      t.string :user_name, comment: 'What the bot should call the user'
      t.text :user_bio, comment: 'What the user wants the bot to know about them'
      t.integer :reply_length, null: false, default: 1, comment: '0=short 1=normal 2=long'
      t.integer :creativity, null: false, default: 2, comment: '0-4, mapped to temperature'
      t.boolean :double_texting, null: false, default: true, comment: 'Send each line of a reply as a separate message'
      t.integer :retention_days, null: false, default: 2, comment: 'DM messages older than this are purged'

      t.timestamps
    end

    # Telegram Stars payments: kept after the user's other data is deleted (needed for refunds & disputes)
    create_table :star_payments do |t|
      t.belongs_to :user, null: false, foreign_key: true, index: true
      t.string :telegram_payment_charge_id, null: false, index: { unique: true }
      t.string :subscription_charge_id, comment: 'telegram_payment_charge_id of the first payment of the subscription'
      t.integer :total_amount, null: false, comment: 'Stars'
      t.string :invoice_payload
      t.datetime :expires_at, null: false, comment: 'Premium access paid for by this payment ends at'
      t.boolean :is_recurring, null: false, default: false
      t.boolean :is_first_recurring, null: false, default: false
      t.datetime :renewal_canceled_at, comment: 'When the bot cancelled renewal (on the user\'s request)'
      t.datetime :refunded_at

      t.timestamps
    end
  end
end
