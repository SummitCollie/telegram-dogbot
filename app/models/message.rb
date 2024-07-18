# frozen_string_literal: true

class Message < ApplicationRecord
  has_one :chat, through: chat_users
  has_one :user, through: chat_users
  belongs_to :chat_user, counter_cache: :num_stored_messages # increment counter on create

  after_create :increment_message_counters

  private

  def increment_message_counters
    # rubocop:disable Rails::SkipsModelValidations
    ChatUser.increment_counter :num_chatuser_messages, chat_user.id
    # rubocop:enable Rails::SkipsModelValidations
  end
end
