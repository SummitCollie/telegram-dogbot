# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :chat_user, counter_cache: :num_stored_messages # increment counter on create
  references :reply_to_message, class_name: 'Message', optional: true
  has_many :replies, class_name: 'Message', foreign_key: 'reply_to_message_id',
                     inverse_of: :replies, dependent: :nullify
  has_one :chat, through: :chat_user
  has_one :user, through: :chat_user
end
