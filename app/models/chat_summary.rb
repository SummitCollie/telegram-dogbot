# frozen_string_literal: true

class ChatSummary < ApplicationRecord
  enum :status, %i[running complete]
  enum :summary_type, %i[default nice vibe_check]

  belongs_to :chat

  after_validation do
    # Delete old ChatSummaries that aren't complete after 5 minutes
    ChatSummary.where(status: :running).where(created_at: ...5.minutes.ago).destroy_all
  end
end
