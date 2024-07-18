# frozen_string_literal: true

class Message < ApplicationRecord
  has_one :chat, through: chat_users
  has_one :user, through: chat_users
  belongs_to :chat_user, counter_cache: :num_stored_messages # increment counter on create

  after_create :increment_chatuser_msg_counter

  private

  def increment_chatuser_msg_counter
    ChatUser.increment_counter :num_total_messages # rubocop:disable Rails::SkipsModelValidations
  end
end
