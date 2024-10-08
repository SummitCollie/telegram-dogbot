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

  def from_this_bot?
    user.is_this_bot
  end

  private

  # Because the production bot runs in webhook mode, it can never know telegram's API IDs
  # for the messages it sends (see TelegramTools#store_bot_output):
  # https://github.com/telegram-bot-rb/telegram-bot?tab=readme-ov-file#async-mode
  def stub_api_id_for_own_messages
    return unless from_this_bot?

    self.api_id = -1
  end
end
