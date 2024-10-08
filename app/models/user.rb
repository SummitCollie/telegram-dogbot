# frozen_string_literal: true

class User < ApplicationRecord
  before_save :set_bot_user_attrs

  has_many :chat_users, dependent: :destroy
  has_many :chats, through: :chat_users
  has_many :messages, through: :chat_users

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
