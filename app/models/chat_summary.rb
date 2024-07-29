# frozen_string_literal: true

class ChatSummary < ApplicationRecord
  enum :status, %i[running complete]
  enum :type, %i[default nice vibe_check]

  belongs_to :chat

  after_find do
    # Delete any ChatSummary if not complete after 5 minutes
    ChatSummary.where(status: :running).where(created_at: ...5.minutes.ago).destroy_all
  end
end
