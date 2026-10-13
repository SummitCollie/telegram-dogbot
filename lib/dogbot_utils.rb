# frozen_string_literal: true

class DogbotUtils
  # Deletes messages older than `default_retention`, except in premium DMs: those are kept for
  # their user's DmSetting#retention_days instead
  def self.delete_messages(default_retention:, now: Time.current)
    retention_days = "COALESCE(dm_settings.retention_days, #{default_retention.in_days.to_i})"
    expired = Message.joins(chat_user: :chat)
                     .joins("LEFT JOIN users dm_users ON chats.api_type = #{Chat.api_types[:private_room]} " \
                            'AND dm_users.api_id = chats.api_id')
                     .joins('LEFT JOIN dm_settings ON dm_settings.user_id = dm_users.id')
                     .where("messages.date < ?::timestamp - make_interval(days => #{retention_days})", now)

    Message.where(id: expired.select(:id)).destroy_all.count
  end

  def self.delete_chat_summaries(older_than:)
    summaries_to_delete = ChatSummary.where(created_at: ...older_than)
    summaries_to_delete.destroy_all.count
  end
end
