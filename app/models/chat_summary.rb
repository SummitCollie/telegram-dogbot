# frozen_string_literal: true

class ChatSummary < ApplicationRecord
  enum :status, { running: 0, complete: 1 }
  enum :summary_type, { default: 0, nice: 1, vibe_check: 2 }

  belongs_to :chat
end
