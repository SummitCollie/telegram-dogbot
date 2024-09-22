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
              FuckyWuckies::SummarizeJobFailure,
              FuckyWuckies::TranslateJobFailure, with: :handle_error

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

  def translate!(first_input_word = nil, *)
    authorize_command!

    run_translate(chat, first_input_word)
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

  def run_translate(chat, first_input_word)
    db_chat = Chat.find_by(api_id: chat.id)
    unless db_chat
      raise FuckyWuckies::TranslateJobFailure.new(
        severity: Logger::Severity::ERROR
      ), "Translate aborted: db_chat ID #{chat.id} not found"
    end

    target_language = detect_target_language(first_input_word)
    text_to_translate = determine_text_to_translate(db_chat, payload, target_language, first_input_word)

    LLM::TranslateJob.perform_later(db_chat, text_to_translate, target_language)
  end

  def detect_target_language(first_input_word)
    candidate = first_input_word&.downcase
    supported_languages = Rails.application.credentials.openai.translate_languages&.map(&:downcase)

    supported_languages.include?(candidate) ? candidate : nil
  end

  def determine_text_to_translate(db_chat, payload, target_language, first_input_word)
    # Text from the "forwarded" message (the message being replied to by the user calling /translate)
    forwarded_message_text = payload.reply_to_message&.text&.strip

    # Text from after the /translate command (ignored if forwarded_message_text exists)
    command_message_text = if target_language
                             payload.text.gsub(/^\/translate(\S?)+ #{Regexp.escape(first_input_word)}/, '').strip
                           else
                             payload.text.gsub(/^\/translate(\S?)+/, '').strip
                           end

    text_to_translate = forwarded_message_text || command_message_text

    if text_to_translate.blank?
      raise FuckyWuckies::TranslateJobFailure.new(
        severity: Logger::Severity::ERROR,
        db_chat:,
        frontend_message: "Translate:\n" \
                          "• Reply to a message, or\n" \
                          "• Paste text after command:\n" \
                          "\t\t\t\t/translate hola mi amigo\n\n" \
                          "Choose target language:\n" \
                          "\t\t\t\t/translate polish hi there!\n\n" \
                          "Supported languages:\n" \
                          "#{Rails.application.credentials.openai.translate_languages.join(', ')}"
      ), "Aborting translation: empty text_to_translate\n" \
         "chat api_id=#{db_chat.id} title=#{db_chat.title}"
    end

    text_to_translate
  end

  def handle_error(error)
    TelegramTools.send_error_message(error, chat.id)
  end
end
