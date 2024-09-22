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
  # Be sure to add any new ones in config/initializers/telegram_bot.rb
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

  def translate!(maybe_to_language = nil, *)
    authorize_command!

    db_chat = Chat.find_by(api_id: chat.id)

    supported_languages = Rails.application.credentials.openai.translate_languages&.map(&:downcase)
    to_language = supported_languages.include?(maybe_to_language) ? maybe_to_language : nil

    quoted_message_text = payload.reply_to_message&.text&.strip

    message_text = if to_language
      payload.text.delete_prefix("/translate #{maybe_to_language}").strip
    else
      payload.text.delete_prefix('/translate').strip
    end

    puts "to_language: #{to_language}"
    puts "message_text: #{message_text}"

    LLM::TranslateJob.perform_later(db_chat, quoted_message_text || message_text, to_language)
  end

  def stats!(*)
    authorize_command!
    # Messages from chat currently stored in DB
    # Total messages seen from chat (including deleted)
    # Message counts per user in a chat (only show top 5 users)
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

    LLM::SummarizeChatJob.perform_later(db_summary)
  rescue StandardError => e
    db_summary&.destroy!
    raise e
  end

  def handle_error(error)
    TelegramTools.send_error_message(error, chat.id)
  end
end
