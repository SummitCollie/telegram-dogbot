# frozen_string_literal: true

module LLM
  # Replies to a premium user's DM, in the persona from their DmSetting. Unlike group replies:
  # - Every message gets a reply, but a burst of messages gets a single one: jobs start after DEBOUNCE,
  #   and skip if a newer message arrived (its job replies instead, seeing all of them).
  # - Only ever uses the self-hosted LLM. If it's down, the user is told it's napping and the job retries.
  # - The reply is streamed in as a draft (see DraftStreamer), instead of a progress message.
  class DirectReplyJob < ReplyJob
    DEBOUNCE = 2.seconds
    RETRY_WAIT = 2.minutes
    RETRY_ATTEMPTS = 15 # ~30 minutes
    NAP_NOTICE_INTERVAL = 30.minutes

    # Replies in the same chat run one at a time, so each sees the previous one's output
    CHAT_LOCKS = Hash.new { |locks, chat_api_id| locks[chat_api_id] = Mutex.new }
    CHAT_LOCKS_MUTEX = Mutex.new
    NAP_NOTICES = {} # rubocop:disable Style/MutableConstant -- chat api_id => when the user was last told
    NAP_NOTICES_MUTEX = Mutex.new

    retry_on FuckyWuckies::LocalLLMUnavailable, wait: RETRY_WAIT, attempts: RETRY_ATTEMPTS do |job, _error|
      job.send(:send_notice, "😴 My brain's still offline, sorry. Try me again in a bit?")
    end

    def self.enqueue(db_message)
      set(wait: DEBOUNCE).perform_later(db_message)
    end

    def perform(db_message)
      @db_message = db_message
      @db_chat = db_message.chat
      @user = db_message.user
      return unless @user.premium?

      chat_lock.synchronize do
        next if superseded?

        reply
      end
    end

    private

    def reply
      setting = @user.dm_setting!
      streamer = DraftStreamer.new(@db_chat)

      begin
        streamer.start
        completion = LLMTools.chat_completion(
          system_prompt: LLMTools.dm_reply_prompt(setting), messages: dm_conversation(history),
          model_params: { temperature: setting.temperature }, progress: streamer, local_only: true
        )
        text = completion.text
        Thread.handle_interrupt(DraftStreamer::Stopped => :never) { streamer.finish }
      rescue DraftStreamer::Stopped
        streamer.finish
        text = streamer.text # keep what was written before the user pressed stop
        return if text.blank?
      end

      if text.blank?
        raise FuckyWuckies::ReplyJobFailure.new(severity: Logger::Severity::ERROR, db_chat: @db_chat),
              "Blank LLM output generating DM reply: chat api_id=#{@db_chat.api_id}"
      end

      send_dm_messages(setting.double_texting ? split_reply(text) : [text])
    rescue FuckyWuckies::LocalLLMUnavailable
      send_nap_notice
      raise
    ensure
      Thread.handle_interrupt(DraftStreamer::Stopped => :never) { streamer&.finish }
    end

    def chat_lock
      CHAT_LOCKS_MUTEX.synchronize { CHAT_LOCKS[@db_chat.api_id] }
    end

    # A newer message from the user has its own job, which will reply to this one too
    def superseded?
      @db_chat.messages.not_from_bot.exists?(['messages.id > ?', @db_message.id]) ||
        Message.from_this_bot.exists?(reply_to_message_id: @db_message.id)
    end

    # The whole stored chat (not just messages before @db_message: replies to earlier messages
    # may have been sent after it). Windowed like ReplyJob#past_messages, to keep the prompt cacheable.
    def history
      scope = @db_chat.messages
      offset = [((scope.count - CONTEXT_MIN_MESSAGES) / CONTEXT_STEP) * CONTEXT_STEP, 0].max

      # Preloaded in separate queries: eager_load (JOINs) gets reply_to_message.user wrong
      scope.preload(:user, reply_to_message: :user)
           .order(:date, :id)
           .offset(offset)
           .to_a
    end

    # Plain turns: the user's messages (no names or IDs needed in a 1:1 chat) and the bot's replies
    def dm_conversation(window)
      turns = order_for_conversation(window).chunk_while { |a, b| a.from_this_bot? == b.from_this_bot? }

      turns.map do |turn_messages|
        role = turn_messages.first.from_this_bot? ? 'assistant' : 'user'
        content = turn_messages.map { |m| role == 'user' ? dm_user_line(m) : m.text }.join("\n")
        { role:, content: }
      end
    end

    def dm_user_line(message)
      reply_to = message.reply_to_message
      prefix = ''
      prefix += "[#{message.attachment_type}] " if message.attachment_type
      if reply_to
        quote = reply_to.text.to_s.squish.truncate(REPLY_QUOTE_LENGTH, separator: ' ')
        prefix += %((replying to #{reply_to.from_this_bot? ? 'you' : 'themself'}: "#{quote}") )
      end
      "#{prefix}#{message.text}"
    end

    # Not shown as Telegram replies: in a 1:1 chat it's obvious what they answer
    def send_dm_messages(texts)
      texts.each_with_index do |text, i|
        sleep SPLIT_MESSAGE_DELAY if i.positive?
        TelegramTools.send_bot_message(@db_chat, text, reply_to: @db_message, collapse: false, protect_content: false)
      end
    end

    # Tells the user once in a while that their messages will be answered later
    def send_nap_notice
      due = NAP_NOTICES_MUTEX.synchronize do
        last = NAP_NOTICES[@db_chat.api_id]
        NAP_NOTICES[@db_chat.api_id] = Time.current if last.nil? || last < NAP_NOTICE_INTERVAL.ago
      end
      return unless due

      send_notice("💤 My brain's offline right now (it runs on my owner's computer). " \
                  "I'll answer as soon as it's back.")
    end

    # Not stored in the DB, so it doesn't end up in the conversation
    def send_notice(text)
      Telegram.bot.async(false) { Telegram.bot.send_message(chat_id: @db_chat.api_id, text:) }
    rescue Telegram::Bot::Error => e
      TelegramTools.logger.warn("Couldn't send notice to chat #{@db_chat.api_id}: #{e.message}")
    end
  end
end
