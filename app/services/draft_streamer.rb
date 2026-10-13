# frozen_string_literal: true

# Streams an LLM reply into a private chat while it's generated, as a Telegram message draft
# (https://core.telegram.org/bots/api#sendmessagedraft): "Thinking…" until output starts, then the text
# so far, with a stop button. Drafts are ephemeral, so the job still sends the final reply as messages.
#
# Same interface as LLMProgress for LLMTools.chat_completion (llm_started, llm_thinking, llm_output).
# Pressing stop raises DraftStreamer::Stopped in the job thread (see .stop), which aborts the LLM request.
class DraftStreamer
  UPDATE_INTERVAL = 1 # seconds between draft updates while text is coming in
  REFRESH_INTERVAL = 20 # seconds; drafts disappear after 30s without an update
  TICK = 0.25 # seconds
  MAX_LENGTH = 4096

  class Stopped < StandardError; end

  REGISTRY = {} # rubocop:disable Style/MutableConstant -- chat api_id => DraftStreamer
  REGISTRY_MUTEX = Mutex.new

  # Handles a `stopped_message_generation` update
  def self.stop(chat_api_id)
    REGISTRY_MUTEX.synchronize { REGISTRY[chat_api_id] }&.stop
  end

  def initialize(db_chat)
    @db_chat = db_chat
    @draft_id = SecureRandom.random_number(1..((2**31) - 1))
    @job_thread = Thread.current
    @mutex = Mutex.new
    @text = +''
  end

  # Output so far (e.g. to keep it when stopped)
  def text
    @mutex.synchronize { @text.dup.strip }
  end

  def start
    REGISTRY_MUTEX.synchronize { REGISTRY[@db_chat.api_id] = self }
    @thread = Thread.new do
      Rails.application.executor.wrap do
        Telegram.bot.async(false) do
          until @mutex.synchronize { @finished }
            safe_tick
            sleep TICK
          end
        end
      end
    end
  end

  # Stops updating the draft. The draft disappears when the bot next sends a message.
  def finish
    @mutex.synchronize { @finished = true }
    REGISTRY_MUTEX.synchronize { REGISTRY.delete(@db_chat.api_id) if REGISTRY[@db_chat.api_id] == self }
    return unless @thread && @thread != Thread.current

    # Updater thread may need to load code to finish its current tick (in development)
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads { @thread.join(10) }
  end

  def stop
    @mutex.synchronize do
      @job_thread.raise(Stopped, "Stopped by user in chat #{@db_chat.api_id}") unless @finished
    end
    nil
  end

  ### Called by LLMTools

  def llm_started(_provider, _messages)
    @mutex.synchronize { @text = +'' }
  end

  def llm_thinking(_thinking); end

  def llm_output(content)
    @mutex.synchronize { @text << content }
  end

  ### Updater thread

  def tick(now = Time.current)
    text = self.text.truncate(MAX_LENGTH)
    changed = text != @last_sent_text
    return unless @last_sent_at.nil? ||
                  (changed && now - @last_sent_at >= UPDATE_INTERVAL) ||
                  now - @last_sent_at >= REFRESH_INTERVAL

    @last_sent_at = now
    @last_sent_text = text
    # Empty text shows a "Thinking…" placeholder
    Telegram.bot.request(:sendMessageDraft, chat_id: @db_chat.api_id, draft_id: @draft_id, text:,
                                            can_stop: true, keep_on_stop: true)
  end

  private

  # Errors mustn't stop the updater for the rest of the reply
  def safe_tick
    tick
  rescue StandardError => e
    TelegramTools.logger.warn("DraftStreamer update failed: #{e.class}: #{e.message}")
  end
end
