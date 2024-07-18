# frozen_string_literal: true

class Chat < ApplicationRecord
  enum :type, %i[private group supergroup channel]

  has_many :users, through: :chat_users
  has_many :messages, through: :chat_users
end
