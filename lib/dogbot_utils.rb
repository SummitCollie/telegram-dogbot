# frozen_string_literal: true

class DogbotUtils
  def self.delete_messages(older_than:)
    msgs_to_delete = Message.where(date: ...older_than)
    msgs_to_delete.destroy_all.count
  end

  def self.delete_chat_summaries(older_than:)
    summaries_to_delete = ChatSummary.where(created_at: ...older_than)
    summaries_to_delete.destroy_all.count
  end
end
