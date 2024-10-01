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
    authorize_message_storage!(payload)
    store_message(payload)

    run_summarize(chat, summary_type: :default)
  end

  def summarize_nicely!(*)
    authorize_command!
    authorize_message_storage!(payload)
    store_message(payload)

    run_summarize(chat, summary_type: :nice)
  end

  def vibe_check!(*)
    authorize_command!
    authorize_message_storage!(payload)
    store_message(payload)

    run_summarize(chat, summary_type: :vibe_check)
  end

  def translate!(first_input_word = nil, *)
    authorize_command!
    authorize_message_storage!(payload)
    store_message(payload)

    command_message_from = payload.from.first_name
    parent_message_from = payload.reply_to_message&.from&.first_name

    run_translate(chat, first_input_word, command_message_from, parent_message_from)
  end

  def stats!(*)
    authorize_command!
    authorize_message_storage!(payload)
    store_message(payload)

    Telegram.bot.send_message(
      chat_id: chat.id,
      protect_content: true,
      text: chat_stats_text
    )
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

  def run_translate(chat, first_input_word, command_message_from, parent_message_from)
    db_chat = Chat.find_by(api_id: chat.id)
    unless db_chat
      raise FuckyWuckies::TranslateJobFailure.new(
        severity: Logger::Severity::ERROR
      ), "Translate aborted: db_chat ID #{chat.id} not found"
    end

    target_language = detect_target_language(first_input_word)
    text_to_translate = determine_text_to_translate(db_chat, payload, target_language, first_input_word)

    LLM::TranslateJob.perform_later(db_chat, text_to_translate, target_language, command_message_from,
                                    parent_message_from)
  end

  def detect_target_language(first_input_word)
    candidate = first_input_word&.downcase
    supported_languages = Rails.application.credentials.openai.translate_languages&.map(&:downcase)

    supported_languages.include?(candidate) ? candidate : nil
  end

  def determine_text_to_translate(db_chat, payload, target_language, first_input_word)
    # Text from (the message being replied to) by the user calling /translate (quote)
    reply_parent_text = payload.reply_to_message&.text&.strip

    # Text from after the /translate command (ignored if reply_parent_text exists)
    command_message_text = if target_language
                             payload.text.gsub(%r{^/translate(\S?)+ #{Regexp.escape(first_input_word)}}, '').strip
                           else
                             payload.text.gsub(%r{^/translate(\S?)+}, '').strip
                           end

    text_to_translate = reply_parent_text || command_message_text

    if text_to_translate.blank?
      raise FuckyWuckies::TranslateJobFailure.new(
        severity: Logger::Severity::ERROR,
        db_chat:,
        frontend_message: "💬 Translate\n" \
                          "• Reply to a message, or\n" \
                          "• Paste text after command:\n" \
                          "\t\t\t\t/translate hola mi amigo\n\n" \
                          "⚙️ Choose target language\n" \
                          "\t\t\t\t/translate polish hi there!\n\n" \
                          "❔ Supported languages\n" \
                          "#{Rails.application.credentials.openai.translate_languages.join(', ')}"
      ), "Aborting translation: empty text_to_translate\n" \
         "chat api_id=#{db_chat.id} title=#{db_chat.title}"
    end

    text_to_translate
  end

  def chat_stats_text
    db_chat = Chat.find_by(api_id: chat.id)
    chat_users = ChatUser.joins(:user).where(chat_id: db_chat.id)

    if db_chat.blank? || chat_users.blank?
      raise FuckyWuckies::NotAGroupChatError.new(
        severity: Logger::Severity::ERROR
      ), 'No chat_users exist yet in this chat'
    end

    top_5_in_db = chat_users.order(num_stored_messages: :desc)
                            .limit(5)
                            .includes(:user)
    top_5_all_time = chat_users.order(num_chatuser_messages: :desc)
                               .limit(5)
                               .includes(:user)

    top_yappers_db = top_5_in_db.map.with_index do |cu, i|
      "\t\t#{i + 1}. #{cu.user.first_name} / #{cu.num_stored_messages} msgs"
    end.join("\n")

    top_yappers_all_time = top_5_all_time.map.with_index do |cu, i|
      "\t\t#{i + 1}. #{cu.user.first_name} / #{cu.num_chatuser_messages} msgs"
    end.join("\n")

    "📊 Chat Stats\n" \
      "Total Messages: #{db_chat.num_messages_total}\n" \
      "Last 2 days: #{db_chat.num_messages_in_db}\n\n" \
      "🗣 Top Yappers (last 2 days):\n#{top_yappers_db}\n\n" \
      "⭐️ Top Yappers (all time):\n#{top_yappers_all_time}"
  end

  def handle_error(error)
    TelegramTools.send_error_message(error, chat.id)
  end
end
