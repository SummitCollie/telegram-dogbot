# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChatSummary do
  # #########################################################
  # TODO: adapt these tests for spec/summarize_helpers
  describe '#after_validation' do
    xit 'deletes any ChatSummary started > 1 minutes ago if still in "running" state' do
      # Create old summary
      old_summary = create(:chat_summary, status: :running, created_at: 6.minutes.ago)

      # Create another summary to run after_validation callback
      create(:chat_summary)

      expect { old_summary.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    xit 'does not delete any ChatSummary started > 5 minutes ago in "complete" state' do
      completed_summary = create(:chat_summary, status: :complete, created_at: 6.minutes.ago)

      # Create another summary to run after_validation callback
      create(:chat_summary)

      expect { completed_summary.reload }.not_to raise_error
    end
  end
end
