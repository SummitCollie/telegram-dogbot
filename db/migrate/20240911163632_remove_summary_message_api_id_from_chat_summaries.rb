# frozen_string_literal: true

class RemoveSummaryMessageApiIdFromChatSummaries < ActiveRecord::Migration[7.1]
  def change
    remove_column :chat_summaries, :summary_message_api_id, :integer
  end
end
