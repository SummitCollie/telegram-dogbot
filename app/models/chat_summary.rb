# frozen_string_literal: true

class ChatSummary < ApplicationRecord
  enum :status, { running: 0, complete: 1 }

  belongs_to :chat
end
