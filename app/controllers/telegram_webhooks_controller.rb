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

  def translate!(*)
    authorize_message_storage!(payload)
    store_message(payload)
    authorize_command!

    command_message_from = payload.from.first_name
    parent_message_from = payload.reply_to_message&.from&.first_name

    run_translate(command_message_from, parent_message_from)
  end

  def chat_stats!(*)
    authorize_message_storage!(payload)
    store_message(payload)
    authorize_command!

    output = chat_stats_text

    TelegramTools.send_bot_message(db_chat, output, protect_content: true)
  end

  def start!(*)
    return unless chat.type == 'private'

    raise FuckyWuckies::AuthorizationError.new(
      severity: Logger::Severity::INFO,
      frontend_message: 'You start! By adding this bot to a group chat ' \
                        'because it has no functionality in DMs or channels.',
      sticker: :heck
    ), 'Not saving message from non-group chat: ' \
       "chat api_id=#{chat.id} username=@#{chat.username}"
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

  ### Handle inline button presses - https://core.telegram.org/bots/api#callbackquery
  def callback_query(data)
    return answer_callback_query('?') unless data == LLMProgress::CANCEL_DATA && payload.message

    answer_callback_query LLMProgress.cancel(
      chat_api_id: payload.message.chat.id, message_id: payload.message.message_id, from:
    )
  end

  ### Handle incoming edited message
  def edited_message(message)
    authorize_message_storage!(message)
    store_edited_message(message)
  end

  private

  def db_chat
    return @db_chat if defined?(@db_chat)

    @db_chat = Chat.find_by(api_id: chat&.id)
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

  def run_translate(command_message_from, parent_message_from)
    target_language, text_to_translate = parse_translate_command

    LLM::TranslateJob.perform_later(db_chat, text_to_translate, target_language, command_message_from,
                                    parent_message_from)
  end

  def handle_error(error)
    TelegramTools.send_error_message(error, chat.id)
  end
end
