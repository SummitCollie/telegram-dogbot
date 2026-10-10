# frozen_string_literal: true

module LLM
  class ReplyJob < ApplicationJob
    # Context window holds between CONTEXT_MIN_MESSAGES and (CONTEXT_MIN_MESSAGES + CONTEXT_STEP - 1)
    # messages. Its start only moves every CONTEXT_STEP messages, so the prompt prefix stays identical
    # between replies and the LLM server can reuse its cached context.
    CONTEXT_MIN_MESSAGES = 300
    CONTEXT_STEP = 100

    # Max length of the quote shown in `reply_to` for replies to this bot's messages
    REPLY_QUOTE_LENGTH = 50

    # For models with `split_replies: true`
    MAX_SPLIT_MESSAGES = 3
    MAX_SPLIT_LINE_LENGTH = 200
    MIN_SPLIT_LINE_WORDS = 2
    SPLIT_MESSAGE_DELAY = 1 # seconds between messages
    LIST_ITEM = /\A([-*•]|\d+[.)])\s/

    discard_on(FuckyWuckies::ReplyJobFailure) do |_job, error|
      raise error
    end

    def perform(db_chat, serialized_message)
      @db_chat = db_chat
      api_message = TelegramTools.deserialize_api_message(serialized_message)
      db_message = @db_chat.messages.find_by(api_id: api_message.message_id)

      # Messages sent before bot was mentioned, plus the message which mentioned the bot
      window = [*past_messages(db_message), db_message]

      LLMProgress.track(@db_chat, label: 'a reply', reply_to: db_message,
                                  requester: db_message.user.api_id) do |progress|
        completion = llm_generate_reply(window, out_of_window_reply_target(window, api_message), progress)
        output_messages = completion.split_replies ? split_reply(completion.text) : [completion.text]
        # Reply replaces the progress message (if shown)
        send_output_messages(output_messages, reply_to: db_message, replace_message_id: progress.handover)
      end
    rescue Faraday::Error => e
      raise FuckyWuckies::ReplyJobFailure.new(
        severity: Logger::Severity::ERROR,
        db_chat: @db_chat
      ), 'Error generating reply to message: ' \
         "chat api_id=#{db_chat.id} title=#{db_chat.title}", cause: e
    end

    # Chat history as alternating turns: other users' messages in `user` turns, one per line like
    # `#123 Name (@username) [photo] replying to #122: text`, and this bot's own messages as `assistant` turns.
    # Every message must render identically between replies (to keep the prompt prefix cacheable),
    # so this only depends on the DB contents of `window` -- except for `extra_reply_target`.
    def conversation(window, extra_reply_target = nil)
      turns = order_for_conversation(window).chunk_while { |a, b| a.from_this_bot? == b.from_this_bot? }

      turns.map do |turn_messages|
        if turn_messages.first.from_this_bot?
          { role: 'assistant', content: turn_messages.map(&:text).join("\n") }
        else
          user_turn(window, turn_messages, (extra_reply_target if turn_messages.last == window.last))
        end
      end
    end

    private

    def user_turn(window, turn_messages, extra_reply_target)
      entries = turn_messages.map { |m| db_message_entry(window, m) }
      if extra_reply_target
        # Insert message being replied to above the last message
        entries.insert(-2, api_message_entry(extra_reply_target))
        entries.last[:reply_to] = "##{entries[-2][:id]}"
      end

      { role: 'user', content: entries.map { |e| LLMTools.chat_log_line(**e) }.join("\n") }
    end

    def past_messages(db_message)
      # Telegram dates have 1s resolution, so tie-break messages from the same second by DB insertion order
      scope = @db_chat.messages.where(
        'messages.date < :date OR (messages.date = :date AND messages.id < :id)',
        date: db_message.date, id: db_message.id
      )
      offset = [((scope.count - CONTEXT_MIN_MESSAGES) / CONTEXT_STEP) * CONTEXT_STEP, 0].max

      scope.includes(:user, reply_to_message: :user)
           .references(:user, :message)
           .order(:date, :id)
           .offset(offset)
           .to_a
    end

    def llm_generate_reply(window, extra_reply_target, progress)
      # Callable: the prompt depends on which model ends up generating the reply
      system_prompt = lambda do |provider|
        "#{LLMTools.reply_prompt(provider)}\nChatroom title: #{@db_chat.title}".tap do |prompt|
          TelegramTools.logger.debug("### System prompt (#{provider.model}):\n#{prompt}")
        end
      end
      messages = conversation(window, extra_reply_target)

      TelegramTools.logger.debug("\n##### Reply to message:\n" \
                                 "### Messages:\n#{messages.map { |m| "[#{m[:role]}]\n#{m[:content]}" }.join("\n")}")

      output = LLMTools.chat_completion(system_prompt:, messages:, progress:)

      if output.text.blank?
        raise FuckyWuckies::ReplyJobFailure.new(
          severity: Logger::Severity::ERROR,
          db_chat: @db_chat
        ), 'Blank LLM output generating reply to message: ' \
           "chat api_id=#{@db_chat.id} title=#{@db_chat.title}"
      end

      output
    end

    # Bot replies go directly after the message they replied to, rather than by date:
    # the bot hadn't seen messages sent while it was generating, and this keeps the
    # previous prompt + reply an exact prefix of the next prompt.
    def order_for_conversation(window)
      replies, others = window.partition { |m| m.from_this_bot? && window.include?(m.reply_to_message) }
      replies_by_target = replies.group_by(&:reply_to_message)

      others.flat_map { |m| [m, *replies_by_target[m]] }
    end

    # If the message being replied to isn't within the window, it needs to be copied into the prompt from
    # the API message: it may not be in the DB at all (the nightly purge deletes messages older than 2 days,
    # and ones sent while the bot wasn't around were never stored). Not needed for replies to this bot's
    # messages, which are quoted in `replying to you ("...")`.
    def out_of_window_reply_target(window, api_message)
      reply_to_message = api_message&.reply_to_message
      return if reply_to_message.blank? || window.last.reply_to_message&.from_this_bot?
      return if window.any? { |m| m.api_id == reply_to_message.message_id }

      reply_to_message
    end

    def db_message_entry(window, message)
      entry = {
        id: message.api_id,
        user: "#{message.user.first_name} (@#{message.user.username})",
        text: message.text,
        attachment: message.attachment_type
      }

      reply_to = message.reply_to_message
      if reply_to&.from_this_bot?
        # Bot's own messages are assistant turns with no visible id, so quote which one instead
        entry[:reply_to] = %(you ("#{reply_to.text.to_s.squish.truncate(REPLY_QUOTE_LENGTH, separator: ' ')}"))
      elsif window.include?(reply_to)
        entry[:reply_to] = "##{reply_to.api_id}"
      end
      entry
    end

    def api_message_entry(message)
      entry = {
        id: message.message_id,
        user: "#{message.from.first_name} (@#{message.from.username})",
        text: message.text,
        attachment: TelegramTools.attachment_type(message)
      }

      entry[:reply_to] = "##{message.reply_to_message.message_id}" if message.reply_to_message.present?
      entry
    end

    # Sends each line as a separate message, like a human double/triple-texting.
    # Longer or list-like output stays in one message.
    def split_reply(text) # rubocop:disable Metrics/CyclomaticComplexity
      lines = text.lines.map(&:strip).compact_blank
      return [text] if lines.size > MAX_SPLIT_MESSAGES ||
                       lines.any? { |line| line.length > MAX_SPLIT_LINE_LENGTH || line.match?(LIST_ITEM) }
      # Models trained on texting often break one thought across lines ("document\neverything"),
      # which would be sent as fragments, so those are joined back into one line
      return [lines.join(' ')] if lines.any? { |line| line.split.size < MIN_SPLIT_LINE_WORDS }

      lines
    end

    # First message replies to the mention, any others follow it like a human double-texting.
    # All are stored as replies to the mention, so they're grouped together in future prompts.
    def send_output_messages(texts, reply_to:, replace_message_id: nil)
      texts.each_with_index do |text, i|
        sleep SPLIT_MESSAGE_DELAY if i.positive?
        send_output_message(text, reply_to:, telegram_reply: i.zero?,
                                  replace_message_id: (replace_message_id if i.zero?))
      end
    end

    def send_output_message(text, reply_to:, telegram_reply:, replace_message_id: nil)
      params = { protect_content: false, disable_notification: true } # bot is chatty enough already
      params[:reply_parameters] = { message_id: reply_to.api_id, allow_sending_without_reply: true } if telegram_reply

      TelegramTools.send_bot_message(@db_chat, text, reply_to:, replace_message_id:, **params)
    end
  end
end
