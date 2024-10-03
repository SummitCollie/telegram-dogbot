# frozen_string_literal: true

class Message < ApplicationRecord
  enum :attachment_type, { animation: 0, audio: 1, document: 2, photo: 3, video: 4, voice: 5 }

  before_create :stub_api_id_for_own_messages

  belongs_to :chat_user, counter_cache: :num_stored_messages # increment counter on create
  belongs_to :reply_to_message, class_name: 'Message', optional: true, inverse_of: :replies
  has_many :replies, class_name: 'Message', foreign_key: :reply_to_message_id,
                     dependent: :nullify, inverse_of: :reply_to_message
  has_one :chat, through: :chat_user
  has_one :user, through: :chat_user

  scope :from_this_bot, -> { joins(:user).where(user: { is_this_bot: true }) }
  scope :not_from_bot, -> { where.not(id: from_this_bot) }

  private

  # Because the production bot runs in webhook mode, it can never know telegram's API IDs
  # for the messages it sends: https://github.com/telegram-bot-rb/telegram-bot?tab=readme-ov-file#async-mode
  # Therefore, I'm setting it to -1 for outgoing messages. See `TelegramTools#store_bot_output`
  def stub_api_id_for_own_messages
    return unless user.is_this_bot

    self.api_id = -1
    # TODO: maybe remove db not-null constraint and set self.api_id = self.id after saving?
  end
end
