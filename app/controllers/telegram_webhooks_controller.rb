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
              FuckyWuckies::SummarizeJobFailure,
              FuckyWuckies::TranslateJobFailure, with: :handle_error

  ### Handle commands
  # Be sure to add any new ones in config/initializers/telegram_bot.rb
  def summarize!(*)
    authorize_command!
    authorize_message_storage!(payload)
    store_message(payload)

    run_summarize(:default)
  end

  def summarize_nicely!(*)
    authorize_command!
    authorize_message_storage!(payload)
    store_message(payload)

    run_summarize(:nice)
  end

  def vibe_check!(*)
    authorize_command!
    authorize_message_storage!(payload)
    store_message(payload)

    run_summarize(:vibe_check)
  end

  def translate!(first_input_word = nil, *)
    authorize_command!
    authorize_message_storage!(payload)
    store_message(payload)

    command_message_from = payload.from.first_name
    parent_message_from = payload.reply_to_message&.from&.first_name

    run_translate(first_input_word, command_message_from, parent_message_from)
  end

  def chat_stats!(*)
    authorize_command!
    authorize_message_storage!(payload)
    store_message(payload)

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
      frontend_message: 'You start! By adding this bot to a group chat ' \
                        'because it has no functionality in DMs or channels.',
      sticker: :heck
    ), 'Not saving message from non-group chat: ' \
       "chat api_id=#{chat.id} username=@#{chat.username}"
  end

  ### Handle unknown commands
  def action_missing(_action, *_args)
    authorize_command!
    authorize_message_storage!(payload)
    store_message(payload)
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
    @db_chat ||= Chat.find_by(api_id: chat.id)
  end

  def reply_when_mentioned(message)
    serialized_message = TelegramTools.serialize_api_message(message)
    LLM::ReplyJob.perform_later(db_chat, serialized_message)
  end

  def run_summarize(summary_type)
    ensure_summarize_allowed!

    db_summary = ChatSummary.create!(
      summary_type:,
      status: 'running',
      chat: db_chat
    )

    LLM::SummarizeChatJob.perform_later(db_summary)
  rescue StandardError => e
    db_summary&.destroy!
    raise e
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
