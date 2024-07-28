# frozen_string_literal: true

class ChatSummary < ApplicationRecord
  enum :status, %i[running complete]
  enum :type, %i[default nice vibe_check]

  belongs_to :chat
  references :first_message, class_name: 'Message', optional: true

  # Delete any ChatSummary if not complete after 5 minutes
  after_find do
    ChatSummary.where(status: :running).where('created_at < ?', 5.minutes.ago).destroy_all
  end
end
