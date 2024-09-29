# frozen_string_literal: true

class Chat < ApplicationRecord
  # _room suffix because `private` is a reserved word in ruby
  enum :api_type, { private_room: 0, group_room: 1, supergroup_room: 2, channel_room: 3 }

  has_many :chat_summaries, dependent: :destroy
  has_many :chat_users, dependent: :destroy
  has_many :users, through: :chat_users
  has_many :messages, through: :chat_users

  def summarize_job_running?
    chat_summaries.exists?(status: :running)
  end

  def messages_since_last_summary(summary_type)
    last_summary = chat_summaries
                   .where(summary_type:, status: :complete)
                   .order(:created_at).last

    if last_summary
      msgs = messages.includes(:user).where('date > ?', last_summary.created_at).order(:date)

      return msgs if msgs.size >= MIN_MESSAGES_BETWEEN_SUMMARIES

      raise FuckyWuckies::SummarizeJobFailure.new(
        db_chat: self,
        frontend_message: "Less than #{MIN_MESSAGES_BETWEEN_SUMMARIES} messages " \
                          'since last summary. Read them yourself!',
        sticker: :no_u
      ), 'Not enough messages since last summary of this type: ' \
         "chat api_id=#{id} summary type=#{summary_type}"
    else
      # No summaries yet so just grab some messages idk
      messages.includes(:user).order(:date).last(200)
    end
  end

  # Count of messages from this chat currently stored in DB
  def num_messages_in_db
    chat_users&.pluck(:num_stored_messages)&.reduce(:+)
  end

  # Count of messages seen in chat (including ones no longer in DB)
  def num_messages_total
    chat_users&.pluck(:num_chatuser_messages)&.reduce(:+)
  end
end
