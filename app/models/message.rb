# frozen_string_literal: true

class Message < ApplicationRecord
  enum :attachment_type, { animation: 0, audio: 1, document: 2, photo: 3, video: 4, voice: 5, sticker: 6 }
  # Images (in vision-enabled chats) are described by LLM::DescribeImageJob, see ImageDescriptions
  enum :image_status, { pending: 0, described: 1, failed: 2 }, prefix: :image

  before_create :stub_api_id_for_own_messages

  belongs_to :chat_user, counter_cache: :num_stored_messages # increment counter on create
  belongs_to :reply_to_message, class_name: 'Message', optional: true, inverse_of: :replies
  has_many :replies, class_name: 'Message', foreign_key: :reply_to_message_id,
                     dependent: :nullify, inverse_of: :reply_to_message
  has_one :chat, through: :chat_user
  has_one :user, through: :chat_user
  # Only photos and images sent as files have their image stored (once downloaded), the rest are just described
  has_one :image, class_name: 'MessageImage', dependent: :delete

  scope :from_this_bot, -> { joins(:user).where(user: { is_this_bot: true }) }
  scope :not_from_bot, -> { where.not(id: from_this_bot) }

  def from_this_bot?
    user.is_this_bot
  end

  # e.g. `photo`, or `photo: a shiba inu in sunglasses` once described
  def attachment_label
    image_description ? "#{attachment_type}: #{image_description}" : attachment_type
  end

  private

  # This bot's messages get their api_id from the send_message response (see TelegramTools#send_bot_message).
  # -1 if the response had no message_id (e.g. stubbed Telegram client in tests).
  def stub_api_id_for_own_messages
    return unless from_this_bot? && api_id.nil?

    self.api_id = -1
  end
end
