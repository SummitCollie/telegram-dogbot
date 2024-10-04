# frozen_string_literal: true

class TelegramWebhooksController
  module ChatStatsHelpers
    module_function

    def chat_stats_text
      chat_users = ChatUser.joins(:user).where(chat_id: db_chat.id)

      if chat_users.blank?
        raise FuckyWuckies::NotAGroupChatError.new(
          severity: Logger::Severity::ERROR
        ), 'No chat_users exist yet in this chat: ' \
           ''
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

      "📊 Chat Stats\n  " \
        "• Total Messages: #{count_total_messages}\n  " \
        "• Last 2 days: #{count_db_messages} (#{percent_db_messages}%)\n\n" \
        "🗣 Top Yappers - 2 days\n#{top_yappers_db}\n\n" \
        "⭐️ Top Yappers - all time\n#{top_yappers_all_time}"
    end
  end
end
