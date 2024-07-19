# frozen_string_literal: true

class User < ApplicationRecord
  has_many :chat_users, dependent: :destroy
  has_many :chats, through: :chat_users
  has_many :messages, through: :chat_users
end
