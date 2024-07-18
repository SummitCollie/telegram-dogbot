# frozen_string_literal: true

class ChatUser < ApplicationRecord
  belongs_to :chat
  belongs_to :user
end
