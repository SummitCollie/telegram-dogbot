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
      message_count = messages.where('date > ?', last_summary.created_at).count

      if message_count < min_messages_between_summaries
        raise FuckyWuckies::SummarizeJobFailure.new(
          db_chat: self,
          frontend_message: "Less than #{min_messages_between_summaries} messages " \
                            'since last summary. Read them yourself!',
          sticker: :no_u
        ), 'Not enough messages since last summary of this type: ' \
           "chat api_id=#{id} summary type=#{summary_type}"
      end

      messages.includes(:user, reply_to_message: [:user])
              .where('messages.date > ?', last_summary.created_at)
              .references(:user, :message)
              .order('messages.date')
    else
      # No summaries yet so just grab the last 200 messages
      messages.includes(:user, reply_to_message: [:user])
              .references(:user, :message)
              .order('messages.date')
              .last(200)
    end
  end

  # Between summaries of same type (nicely, vibe_check, etc)
  def min_messages_between_summaries
    100
  end

  # Count of messages from this chat currently stored in DB
  def num_messages_in_db
    chat_users.joins(:user)
              .where(user: { is_this_bot: false })
              .sum(:num_stored_messages)
  end

  # Count of messages seen in chat (including ones no longer in DB)
  def num_messages_total
    chat_users.joins(:user)
              .where(user: { is_this_bot: false })
              .sum(:num_chatuser_messages)
  end
end
