# frozen_string_literal: true

class ChatSummary < ApplicationRecord
  enum :status, { running: 0, complete: 1 }
  enum :summary_type, { default: 0, nice: 1, vibe_check: 2 }

  belongs_to :chat

  # Summaries which will have (jump to prev/next) buttons appended to the end
  scope :linkable, -> { where.not(summary_type: :vibe_check) }

  after_validation do
    # Delete old ChatSummaries that aren't complete after 5 minutes
    ChatSummary.where(status: :running).where(created_at: ...5.minutes.ago).destroy_all
  end
end
