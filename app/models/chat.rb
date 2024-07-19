# frozen_string_literal: true

class Chat < ApplicationRecord
  # _room suffix because `private` is reserved
  enum :api_type, %i[private_room group_room supergroup_room channel_room]

  has_many :users, through: :chat_users
  has_many :messages, through: :chat_users
end
