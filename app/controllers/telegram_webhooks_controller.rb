# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include AuthorizationHandler
  include ChatStatsHelpers
  include MessageStorage
  include ReplyHelpers
  include SummarizeHelpers
  include TranslateHelpers

  # Auto typecast to types from telegram-bot-types gem
  include Telegram::Bot::UpdatesController::TypedUpdate

  rescue_from FuckyWuckies::AuthorizationError,
              FuckyWuckies::NotAGroupChatError,
              FuckyWuckies::ChatNotWhitelistedError,
              FuckyWuckies::MessageFilterError,
              FuckyWuckies::MissingArgsError,
              FuckyWuckies::SummarizeJobFailure,
              FuckyWuckies::TranslateJobFailure, with: :handle_error

  # Validate `telegram_secret_token` from rails credentials
  def initialize(bot = nil, update = nil, webhook_request = nil)
    if webhook_request && !Rails.env.test?
      secret_token_header = webhook_request.headers.fetch('X-Telegram-Bot-Api-Secret-Token')
      if secret_token_header != Rails.application.credentials.telegram_secret_token
        raise FuckyWuckies::AuthorizationError.new(
          severity: Logger::Severity::ERROR
        ), "Unauthorized webhook request: ip=#{webhook_request.ip}"
      end
    end

    super
  end

  ### Handle commands
  # Be sure to add any new ones in config/initializers/telegram_bot.rb
  def summarize!(*)
    authorize_message_storage!(payload)
    store_message(payload)
    authorize_command!

    Telegram.bot.send_message(
      chat_id: chat.id,
      protect_content: false,
      text: summarize_help_text,
      parse_mode: 'HTML'
    )
  end

  def summarize_url!(*)
    authorize_message_storage!(payload)
    store_message(payload)
    authorize_command!

    run_summarize_url
  end

  def summarize_chat!(*)
    authorize_message_storage!(payload)
    store_message(payload)
    authorize_command!

    style = TelegramTools.strip_bot_command('summarize_chat', payload.text)
    summary_type = if style.blank? then :default else :custom end # rubocop:disable Style/OneLineConditional

    run_summarize_chat(summary_type, style:)
  end

  def vibe_check!(*)
    authorize_message_storage!(payload)
    store_message(payload)
    authorize_command!

    run_summarize_chat(:vibe_check)
  end

  def translate!(first_input_word = nil, *)
    authorize_message_storage!(payload)
    store_message(payload)
    authorize_command!

    command_message_from = payload.from.first_name
    parent_message_from = payload.reply_to_message&.from&.first_name

    run_translate(first_input_word, command_message_from, parent_message_from)
  end

  def chat_stats!(*)
    authorize_message_storage!(payload)
    store_message(payload)
    authorize_command!

    output = chat_stats_text

    Telegram.bot.send_message(
      chat_id: chat.id,
      protect_content: true,
      text: output
    )
    TelegramTools.store_bot_output(db_chat, output)
  end

  def start!(*)
    return unless chat.type == 'private'

    raise FuckyWuckies::AuthorizationError.new(
      severity: Logger::Severity::INFO,
      frontend_message: "This bot only functions in group chats!\n\n" \
                        'The only thing you can do in DMs is use the /opt_out command, ' \
                        'if you want the bot to ignore you globally across every chat.',
      sticker: :heck
    ), 'Not saving message from non-group chat: ' \
       "chat api_id=#{chat.id} username=@#{chat.username}"
  end

  def opt_out!(*)
    return unless chat.type == 'private'

    db_user = User.find_or_initialize_by(api_id: from.id)
    Telegram.bot.send_message(
      chat_id: chat.id,
      parse_mode: 'HTML',
      text: UserOptOut.infotext(db_user),
      link_preview_options: { is_disabled: true }
    )
  end

  def i_hate_you_and_never_want_to_see_you_again!(*)
    return unless chat.type == 'private'

    db_user = User.find_or_create_by(api_id: from.id)
    UserOptOut.opt_out(db_user)

    Telegram.bot.send_sticker(
      chat_id: chat_api_id,
      sticker: TG_🐺♋🖼️_STICKERS_🌶️🍆💦[:cry]
    )
    Telegram.bot.send_message(
      chat_id: chat.id,
      parse_mode: 'HTML',
      text: "⭕️ You have opted out and are now invisible to the bot across every chat.\n\n" \
            "Use <code>/im_deeply_sorry_please_take_me_back</code> to opt back in anytime."
    )
  end

  def im_deeply_sorry_please_take_me_back!(*)
    return unless chat.type == 'private'

    db_user = User.find_by(api_id: from.id)
    UserOptOut.opt_in(db_user)

    Telegram.bot.send_message(
      chat_id: chat.id,
      text: "🟢 I think I can forgive you just this once! [opt-in success]"
    )
  end

  ### Handle unknown commands
  def action_missing(_action, *_args)
    authorize_message_storage!(payload)
    store_message(payload)
    authorize_command!
  end

  ### Handle incoming message - https://core.telegram.org/bots/api#message
  def message(message)
    authorize_message_storage!(message)
    store_message(message)
    reply_when_mentioned(message) if bot_mentioned? || replied_to_bot?
  end

  ### Handle incoming edited message
  def edited_message(message)
    authorize_message_storage!(message)
    store_edited_message(message)
  end

  private

  def db_chat
    @db_chat ||= Chat.find_by(api_id: chat&.id)
  end

  def reply_when_mentioned(message)
    serialized_message = TelegramTools.serialize_api_message(message)
    LLM::ReplyJob.perform_later(db_chat, serialized_message)
  end

  def run_summarize_chat(summary_type, style: nil)
    ensure_summarize_allowed!

    summary = ChatSummary.create!(
      chat: db_chat,
      status: 'running',
      summary_type:,
      style: style.presence
    )

    LLM::SummarizeChatJob.perform_later(summary)
  rescue StandardError => e
    summary&.destroy!
    raise e
  end

  def run_summarize_url
    url, style_text = parse_summarize_url_command
    LLM::SummarizeUrlJob.perform_later(db_chat, url, style_text)
  end

  def run_translate(first_input_word, command_message_from, parent_message_from)
    target_language = detect_target_language(first_input_word)
    text_to_translate = determine_text_to_translate(target_language, first_input_word)

    LLM::TranslateJob.perform_later(db_chat, text_to_translate, target_language, command_message_from,
                                    parent_message_from)
  end

  def handle_error(error)
    TelegramTools.send_error_message(error, chat.id)
  end
end
