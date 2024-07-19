# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :chat_user, counter_cache: :num_stored_messages # increment counter on create
  has_one :chat, through: :chat_user
  has_one :user, through: :chat_user
end
