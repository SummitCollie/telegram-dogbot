# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  self.log_arguments = false

  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # Someone pressed the progress message's cancel button (see LLMProgress)
  discard_on(LLMProgress::Cancelled) do |_job, error|
    TelegramTools.logger.info(error.message)
  end
end
