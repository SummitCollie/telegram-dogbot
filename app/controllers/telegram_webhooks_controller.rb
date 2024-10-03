# frozen_string_literal: true

# rubocop:disable Layout/LineContinuationLeadingSpace
class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include AuthorizationHandler
  include MessageStorage
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
    TelegramTools.store_bot_output(db_chat, output) # TODO: anywhere else?
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

    # Don't bother saving calls to start command idc about it
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
    reply_when_mentioned if bot_mentioned? || replied_to_bot?
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

  def bot_mentioned?
    TelegramTools.extract_message_text(payload).downcase.include?("@#{
      Rails.application.credentials.telegram.bot.username.downcase
    }")
  end

  def replied_to_bot?
    payload.reply_to_message.present?
  end

  def reply_when_mentioned
    puts '=================== should send reply!'
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

  def chat_stats_text
    chat_users = ChatUser.joins(:user).where(chat_id: db_chat.id)

    if chat_users.blank?
      raise FuckyWuckies::NotAGroupChatError.new(
        severity: Logger::Severity::ERROR
      ), 'No chat_users exist yet in this chat: ' \
         ""
    end

    # total count of messages seen in chat (including deleted from db)
    count_total_messages = db_chat.num_messages_total

    top_5_all_time = chat_users.order(num_chatuser_messages: :desc)
                               .limit(5)
                               .includes(:user)

    top_yappers_all_time = top_5_all_time.map.with_index do |cu, i|
      "  #{i + 1}. #{cu.user.first_name} / #{cu.num_chatuser_messages} msgs " \
        "(#{((cu.num_chatuser_messages.to_f / count_total_messages) * 100).round(1)}%)"
    end.join("\n")

    # count of messages currently stored in db
    count_db_messages = db_chat.num_messages_in_db
    percent_db_messages = ((count_db_messages.to_f / count_total_messages) * 100).round(3)

    top_5_in_db = chat_users.order(num_stored_messages: :desc)
                            .limit(5)
                            .includes(:user)

    top_yappers_db = top_5_in_db.map.with_index do |cu, i|
      "  #{i + 1}. #{cu.user.first_name} / #{cu.num_stored_messages} msgs " \
        "(#{((cu.num_stored_messages.to_f / count_db_messages) * 100).round(1)}%)"
    end.join("\n")

    "📊 Chat Stats\n" \
      "  • Total Messages: #{count_total_messages}\n" \
      "  • Last 2 days: #{count_db_messages} (#{percent_db_messages}%)\n\n" \
      "🗣 Top Yappers - 2 days\n#{top_yappers_db}\n\n" \
      "⭐️ Top Yappers - all time\n#{top_yappers_all_time}"
  end

  def handle_error(error)
    TelegramTools.send_error_message(error, chat.id)
  end
end
# rubocop:enable Layout/LineContinuationLeadingSpace
