# frozen_string_literal: true

# "Domino's tracker" for LLM tasks. Shows "typing..." at first; if the task takes longer than
# SHOW_AFTER, posts a silent message with the task's progress (waking up the model, reading the
# prompt, writing), updated as it goes, with a cancel button. When done, callers either edit their
# output into it (`handover`), or let it be deleted (`finish`, automatic at the end of `track`).
#
#   LLMProgress.track(db_chat, label: 'a reply', reply_to: db_message) do |progress|
#     LLMTools.chat_completion(..., progress:)
#   end
#
# Updates run in a background thread. Cancelling raises LLMProgress::Cancelled in the tracked (job)
# thread, which aborts the LLM request. The registry used to find trackers when their cancel button is
# pressed is per-process, which is fine for a single puma worker.
class LLMProgress
  SHOW_AFTER = 5 # seconds
  UPDATE_INTERVAL = 2.5 # seconds; Telegram rate-limits edits
  TYPING_INTERVAL = 4 # seconds; typing indicator lasts ~5s
  MODEL_CHECK_INTERVAL = 2 # seconds
  TICK = 0.5 # seconds
  CHARS_PER_TOKEN = 3.5 # rough prompt token estimate
  CANCEL_DATA = 'llm_progress_cancel'
  CANCEL_KEYBOARD = { inline_keyboard: [[{ text: '✖️ Cancel', callback_data: CANCEL_DATA }]] }.freeze

  class Cancelled < StandardError; end

  REGISTRY = {} # rubocop:disable Style/MutableConstant -- [chat api_id, message api_id] => LLMProgress
  REGISTRY_MUTEX = Mutex.new

  class << self
    # - label: what's being worked on, e.g. 'a reply'
    # - reply_to: DB Message the progress message replies to
    # - requester: Telegram user ID allowed to cancel (besides the bot's owner); nil lets anyone cancel
    def track(db_chat, label:, reply_to: nil, requester: nil)
      progress = new(db_chat, label:, reply_to:, requester:)
      progress.start
      yield progress
    ensure
      # Mustn't be interrupted by a cancel, or the updater thread could be left running
      Thread.handle_interrupt(Cancelled => :never) { progress&.finish }
    end

    # Handles the cancel button. Returns text to show whoever pressed it.
    def cancel(chat_api_id:, message_id:, from:)
      progress = REGISTRY_MUTEX.synchronize { REGISTRY[[chat_api_id, message_id]] }
      return progress.cancel(from) if progress

      # Not tracked by this process (e.g. its job died in a restart), so just clean up the message
      Telegram.bot.async(false) { Telegram.bot.delete_message(chat_id: chat_api_id, message_id:) }
      'Already finished'
    rescue Telegram::Bot::Error
      'Already finished'
    end
  end

  def initialize(db_chat, label:, reply_to: nil, requester: nil, now: Time.current)
    @db_chat = db_chat
    @label = label
    @reply_to = reply_to
    @requester = requester
    @job_thread = Thread.current
    @mutex = Mutex.new
    @started_at = now
    @stage = :preparing
    @stage_times = { preparing: now }
  end

  def start
    @thread = Thread.new do
      Rails.application.executor.wrap do
        Telegram.bot.async(false) do
          until @mutex.synchronize { @finished }
            tick
            sleep TICK
          end
        end
      end
    rescue StandardError => e
      TelegramTools.logger.error("LLMProgress updater crashed: #{e.class}: #{e.message}")
    end
  end

  ### Called by LLMTools

  # About to send `messages` to `provider` (again, on fallback to another provider)
  def llm_started(provider, messages, now: Time.current)
    prompt_chars = messages.sum { |m| m[:content].to_s.length }
    @mutex.synchronize do
      @provider = provider
      @model_info = nil
      @loaded_at_start = nil
      @prompt_tokens = (prompt_chars / CHARS_PER_TOKEN).round
      @tokens_out = 0
      enter_stage(provider.self_hosted ? :waking_model : :reading_prompt, now)
    end
  end

  def llm_output(_content, now: Time.current)
    @mutex.synchronize do
      enter_stage(:writing, now) unless @stage == :writing
      @tokens_out += 1 # roughly one token per streamed chunk
    end
  end

  ### Called by the job when done

  # Stops updating the progress message and returns its api_id (nil if it was never shown),
  # so the caller can edit its output into it instead of it being deleted
  def handover
    stop_updates
    @mutex.synchronize do
      @handed_over = true
      @message_id
    end
  end

  # Stops updating, and deletes the progress message unless it was handed over
  def finish
    stop_updates
    message_id, handed_over = @mutex.synchronize { [@message_id, @handed_over] }
    return unless message_id

    REGISTRY_MUTEX.synchronize { REGISTRY.delete([@db_chat.api_id, message_id]) }
    delete_message(message_id) unless handed_over || @deleted
  end

  ### Called from the cancel button

  def cancel(from)
    owner = Rails.application.credentials.telegram.bot.owner_username
    unless @requester.nil? || from.id == @requester || from.username == owner
      return "Only whoever asked (or @#{owner}) can cancel this"
    end

    @mutex.synchronize do
      return 'Too late, already done' if @finished

      @job_thread.raise(Cancelled, "Cancelled by @#{from.username}")
    end
    'Cancelled'
  end

  ### Updater thread

  def tick(now = Time.current)
    check_model(now)

    if @message_id.nil?
      @send_failed || now - @started_at < SHOW_AFTER ? send_typing(now) : send_message(now)
    elsif now - @last_edit_at >= UPDATE_INTERVAL
      edit_message(now)
    end
  end

  def render(now = Time.current)
    @mutex.synchronize do
      [
        "🐶 <b>Working on #{h @label}…</b> #{duration(now - @started_at)}",
        *step_lines(now),
        (model_line if @provider)
      ].compact.join("\n")
    end
  end

  private

  def enter_stage(stage, now)
    # Stages can be skipped, e.g. output starting while a check whether the model is loaded was still
    # in flight. Count them as done instantly, so rendering them as done has their times.
    STAGE_ORDER[(STAGE_ORDER.index(@stage) + 1)...STAGE_ORDER.index(stage)].each { |s| @stage_times[s] = now }
    @stage = stage
    @stage_times[stage] = now
  end

  def stop_updates
    @mutex.synchronize { @finished = true }
    return unless @thread && @thread != Thread.current

    # Updater thread may need to load code to finish its current tick (in development)
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads { @thread.join(10) }
  end

  # While waking up a self-hosted model, check whether it's loaded yet
  def check_model(now)
    provider = provider_to_check(now)
    return unless provider

    info = LocalInferenceApi.loaded_model(provider.model)
    @mutex.synchronize do
      @loaded_at_start = info.present? if @loaded_at_start.nil?
      if info && @stage == :waking_model
        @model_info = info
        enter_stage(:reading_prompt, now)
      end
    end
  end

  # Provider whose model to check is loaded, if waking it and due for a check
  def provider_to_check(now)
    @mutex.synchronize do
      next unless @stage == :waking_model
      next if @model_checked_at && now - @model_checked_at < MODEL_CHECK_INTERVAL

      @model_checked_at = now
      @provider
    end
  end

  def send_typing(now)
    return if @last_typing_at && now - @last_typing_at < TYPING_INTERVAL

    @last_typing_at = now
    Telegram.bot.send_chat_action(chat_id: @db_chat.api_id, action: 'typing')
  rescue Telegram::Bot::Error => e
    TelegramTools.logger.debug("LLMProgress typing failed: #{e.message}")
  end

  def send_message(now)
    text = render(now)
    params = { chat_id: @db_chat.api_id, text:, parse_mode: 'HTML', disable_notification: true,
               reply_markup: CANCEL_KEYBOARD }
    params[:reply_parameters] = { message_id: @reply_to.api_id, allow_sending_without_reply: true } if @reply_to

    response = Telegram.bot.send_message(**params)
    message_id = response.dig('result', 'message_id') if response.is_a?(Hash)
    @last_text = text
    @last_edit_at = now
    @mutex.synchronize { @message_id = message_id }
    REGISTRY_MUTEX.synchronize { REGISTRY[[@db_chat.api_id, message_id]] = self } if message_id
  rescue Telegram::Bot::Error => e
    # Don't retry every tick; keep just showing "typing..."
    @send_failed = true
    TelegramTools.logger.warn("LLMProgress message failed to send: #{e.message}")
  end

  def edit_message(now)
    text = render(now)
    return if text == @last_text

    @last_text = text
    @last_edit_at = now
    Telegram.bot.edit_message_text(chat_id: @db_chat.api_id, message_id: @message_id, text:, parse_mode: 'HTML',
                                   reply_markup: CANCEL_KEYBOARD)
  rescue Telegram::Bot::Error => e
    TelegramTools.logger.debug("LLMProgress edit failed: #{e.message}")
  end

  def delete_message(message_id)
    Telegram.bot.async(false) { Telegram.bot.delete_message(chat_id: @db_chat.api_id, message_id:) }
    @mutex.synchronize { @deleted = true }
  rescue Telegram::Bot::Error => e
    TelegramTools.logger.debug("LLMProgress delete failed: #{e.message}")
  end

  ### Rendering (called with @mutex held)

  def step_lines(now)
    return ["⏳ Getting ready… #{duration(now - @started_at)}"] unless @provider

    steps = []
    steps << step_line(:waking_model, 'Wake up model', now) if @provider.self_hosted
    steps << step_line(:reading_prompt, 'Read messages', now)
    steps << step_line(:writing, "Write #{h @label.delete_prefix('a ').delete_prefix('an ')}", now)
  end

  STAGE_ORDER = %i[preparing waking_model reading_prompt writing].freeze
  private_constant :STAGE_ORDER

  def step_line(stage, name, now)
    current = STAGE_ORDER.index(@stage)
    index = STAGE_ORDER.index(stage)
    return "▫️ #{name}" if index > current

    detail = index == current ? current_detail(stage, now) : done_detail(stage)
    "#{index == current ? '⏳' : '✅'} #{name}#{" · #{detail}" if detail}"
  end

  def current_detail(stage, now)
    elapsed = now - @stage_times[stage]
    case stage
    when :waking_model then duration(elapsed)
    when :reading_prompt then ["~#{count(@prompt_tokens)} tokens", prompt_eta(elapsed)].compact.join(' · ')
    when :writing then "#{count(@tokens_out)} tokens · #{(@tokens_out / [elapsed, 1].max).round(1)} tok/s"
    end
  end

  def done_detail(stage)
    next_stage = STAGE_ORDER[STAGE_ORDER.index(stage) + 1]
    return 'already awake' if stage == :waking_model && @loaded_at_start

    took = duration(@stage_times[next_stage] - @stage_times[stage])
    stage == :reading_prompt ? "~#{count(@prompt_tokens)} tokens · #{took}" : took
  end

  # Upper bound: assumes none of the prompt is cached
  def prompt_eta(elapsed)
    speed = @provider.self_hosted && LocalInferenceApi.prompt_tokens_per_second
    return unless speed

    remaining = (@prompt_tokens / speed) - elapsed
    remaining.positive? ? "up to ~#{duration(remaining)} left" : 'any second now'
  end

  def model_line
    if @provider.self_hosted
      context = @model_info&.dig('context_length') || LocalInferenceApi.config&.request_params&.dig(:options, :num_ctx)
    end
    "<i>#{h @provider.model.to_s.split('/').last}#{" · #{(context / 1024.0).round}k context" if context}</i>"
  end

  def duration(seconds)
    seconds = seconds.round
    seconds < 60 ? "#{seconds}s" : format('%<m>dm %<s>02ds', m: seconds / 60, s: seconds % 60)
  end

  def count(number)
    number >= 1000 ? "#{(number / 1000.0).round(1).to_s.delete_suffix('.0')}k" : number.to_s
  end

  def h(text) = ERB::Util.html_escape(text)
end
