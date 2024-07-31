# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include AuthorizationHandler
  include MessageStorage
  include SummarizeHelpers

  # Auto typecast to types from telegram-bot-types gem
  include Telegram::Bot::UpdatesController::TypedUpdate

  rescue_from FuckyWuckies::AuthorizationError,
              FuckyWuckies::NotAGroupChatError,
              FuckyWuckies::ChatNotWhitelistedError,
              FuckyWuckies::MessageFilterError,
              FuckyWuckies::SummarizeJobFailure, with: :handle_error

  ### Handle commands
  # Be sure to add any new ones in config/initializers/register_telegram_bot.rb
  def summarize!(*)
    authorize_command!

    run_summarize(chat, summary_type: :default)
  end

  def summarize_nicely!(*)
    authorize_command!

    run_summarize(chat, summary_type: :nice)
  end

  def vibe_check!(*)
    authorize_command!

    run_summarize(chat, summary_type: :vibe_check)
  end

  def stats!(*)
    authorize_command!
    # Messages from chat currently stored in DB
    # Total messages seen from chat (including deleted)
    # Message counts per user in a chat (only show top 5 users)
  end

  ### Handle unknown commands
  def action_missing(_action, *_args)
    return unless action_type == :command

    authorize_command!

    reply_with :message, text: 'Invalid command!'
  end

  ### Handle incoming message - https://core.telegram.org/bots/api#message
  def message(message)
    authorize_message_storage!(message)

    store_message(message)
  end

  ### Handle incoming edited message
  def edited_message(message)
    authorize_message_storage!(message)

    store_edited_message(message)
  end

  private

  def run_summarize(chat, summary_type:)
    db_chat = Chat.find_by(api_id: chat.id)
    ensure_summarize_allowed!(db_chat:)

    db_summary = ChatSummary.create!(
      summary_type:,
      status: 'running',
      chat: db_chat
    )

    CloudflareAi::SummarizeChatJob.perform_later(db_summary)
  rescue StandardError => e
    db_summary&.destroy!
    raise e
  end

  def handle_error(error)
    logger.log(error.severity, error.message)
    bot.send_sticker(chat_id: chat.id, sticker: TG_🐺♋🖼️_STICKERS_🌶️🍆💦[error.sticker]) if error.sticker
    respond_with :message, text: error.frontend_message if error.frontend_message
  end
end
