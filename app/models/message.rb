# frozen_string_literal: true

class Message < ApplicationRecord
  enum :attachment_type, { animation: 0, audio: 1, document: 2, photo: 3, video: 4, voice: 5 }

  belongs_to :chat_user, counter_cache: :num_stored_messages # increment counter on create
  belongs_to :reply_to_message, class_name: 'Message', optional: true, inverse_of: :replies
  has_many :replies, class_name: 'Message', foreign_key: :reply_to_message_id,
                     dependent: :nullify, inverse_of: :reply_to_message
  has_one :chat, through: :chat_user
  has_one :user, through: :chat_user
end
