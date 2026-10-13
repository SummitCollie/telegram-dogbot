# frozen_string_literal: true

# Tracks which messages' images are being described (by LLM::DescribeImageJob), so replies can wait until
# everything in their context is described. Each image is queued once, when it's sent; replies queue any still
# pending again, e.g. ones sent while the self-hosted model was unavailable, or lost in a restart.
#
# Per-process, like LLMProgress::REGISTRY: fine for a single puma worker running jobs in-process (:async).
class ImageDescriptions
  MUTEX = Mutex.new
  FINISHED = ConditionVariable.new
  IN_FLIGHT = Set.new # message ids

  class << self
    # Queues describing each of `messages` that's pending, unless already queued.
    # Returns the ids of those pending.
    def request(messages)
      pending_ids = messages.select { |m| m.is_a?(Message) && m.image_pending? }.map(&:id)
      new_ids = MUTEX.synchronize { pending_ids.select { |id| IN_FLIGHT.add?(id) } }
      # Outside the lock: the test adapter can run jobs right away, and they call `finished`
      new_ids.each { |id| LLM::DescribeImageJob.perform_later(id) }
      pending_ids
    end

    # Blocks until none of `message_ids` are being described, yielding how many still are whenever one finishes
    def wait_for(message_ids)
      MUTEX.synchronize do
        loop do
          remaining = (IN_FLIGHT & message_ids).size
          yield remaining if block_given?
          break if remaining.zero?

          FINISHED.wait(MUTEX)
        end
      end
    end

    # Called by LLM::DescribeImageJob when it's done, whether or not it could describe the image
    def finished(message_id)
      MUTEX.synchronize do
        IN_FLIGHT.delete(message_id)
        FINISHED.broadcast
      end
    end

    def reset!
      MUTEX.synchronize { IN_FLIGHT.clear }
    end
  end
end
