# frozen_string_literal: true

class ChatUser < ApplicationRecord
  has_many :messages, dependent: :destroy
  belongs_to :chat
  belongs_to :user
end
