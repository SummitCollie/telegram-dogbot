# frozen_string_literal: true

class Chat < ApplicationRecord
  # _room suffix because `private` is a reserved word in ruby
  enum :api_type, %i[private_room group_room supergroup_room channel_room]

  has_many :chat_summaries, dependent: :destroy
  has_many :chat_users, dependent: :destroy
  has_many :users, through: :chat_users
  has_many :messages, through: :chat_users

  def summarize_job_running?
    chat_summaries.exists?(status: :running)
  end

  def messages_since_last_summary(type:)
    if (last_summary = chat_summaries.order(:created_at).limit(1))
      msgs = messages.where('date > ?', last_summary.created_at)

      return msgs if msgs.count > MIN_MESSAGES_BETWEEN_SUMMARIES

      # Ran the same type of summary too recently
      if last_summary.type == type
        raise FuckyWuckies::SummarizeJobFailure.new(
          frontend_message: "Less than #{MIN_MESSAGES_BETWEEN_SUMMARIES} messages " \
                            'since last summary. Read them yourself!',
          sticker: :no_u
        ), 'Not enough messages since last summary of this type: ' \
           "chat api_id=#{chat.id} summary type=#{type}"
      end

      # Return messages since last summary of other type
      msgs = messages.where('date > ?', last_summary.first_message.date)
    else
      # No summaries yet so just grab some messages idk
      messages.order(:date).last(200)
    end
  end
end
