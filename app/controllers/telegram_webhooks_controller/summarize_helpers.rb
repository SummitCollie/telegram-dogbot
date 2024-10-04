# frozen_string_literal: true

class TelegramWebhooksController
  module SummarizeHelpers
    extend self

    def ensure_summarize_allowed!
      # Delete old ChatSummaries that aren't complete after 1 minute
      db_chat.chat_summaries.where(status: :running, created_at: ...1.minute.ago).destroy_all

      return unless db_chat&.summarize_job_running?

      raise FuckyWuckies::SummarizeJobFailure.new(
        frontend_message: 'Still working on another summary!!',
        sticker: :heavy_typing
      ), 'Summarize job already in progress: ' \
         "chat api_id=#{chat.id}"
    end
  end
end
