# frozen_string_literal: true

class User < ApplicationRecord
  before_save :set_bot_user_attrs

  has_many :chat_users, dependent: :destroy
  has_many :chats, through: :chat_users
  has_many :messages, through: :chat_users
  has_one :dm_setting, dependent: :destroy
  has_many :star_payments, dependent: :restrict_with_exception

  def owner?
    username.present? && username == Rails.application.credentials.telegram.bot.owner_username
  end

  # End of the premium access paid for so far, or nil if never paid
  def premium_until
    star_payments.not_refunded.maximum(:expires_at)
  end

  # Allowed to DM the bot (the owner always is)
  def premium?
    owner? || premium_until&.future? || false
  end

  # Most recent payment of the user's current subscription
  def current_payment
    star_payments.not_refunded.where('expires_at > ?', Time.current).order(:expires_at).last
  end

  def dm_setting!
    dm_setting || create_dm_setting!
  end

  # The bot's private chat with this user (private chats' IDs are their users' IDs)
  def dm_chat
    Chat.private_room.find_by(api_id:)
  end

  # Deletes all stored messages of the user's DMs with the bot (both sides). Returns how many.
  def forget_dms!
    chat = dm_chat
    return 0 unless chat

    Message.where(id: chat.messages.select(:id)).destroy_all.count
  end

  private

  # Set username, first_name, etc for this bot's user whenever it's created/updated
  def set_bot_user_attrs
    return unless is_this_bot

    self.api_id = -1
    self.is_bot = true
    self.username = Rails.application.credentials.telegram.bot.username
    self.first_name = Rails.application.credentials.telegram.bot.first_name
  end
end
