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

  def messages_to_summarize(summary_type)
    last_summary = last_summary_of_type(summary_type)

    # If no summaries of this type yet, just grab the last 200 messages
    return last_n_messages(200) unless last_summary

    num_msgs_since_summary = messages.where('date > ?', last_summary.created_at).count

    # Plenty of messages -- ignore msgs older than last summary
    return messages_since_summary(last_summary) if num_msgs_since_summary >= min_messages_between_summaries

    # Not really enough messages to ignore msgs older than last summary,
    # so just grab the last 200
    last_n_messages(200)
  end

  # Threshold between summaries of same type (default, vibe_check, etc):
  # if we have more messages than this number, ignore any messages sent
  # before the last summary
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

  private

  def last_summary_of_type(summary_type)
    chat_summaries
      .where(summary_type:, status: :complete)
      .order(:created_at).last
  end

  def messages_since_summary(chat_summary)
    messages.includes(:user, reply_to_message: [:user])
            .where('messages.date > ?', chat_summary.created_at)
            .references(:user, :message)
            .order('messages.date')
  end

  def last_n_messages(n) # rubocop:disable Naming/MethodParameterName
    messages.includes(:user, reply_to_message: [:user])
            .references(:user, :message)
            .order('messages.date')
            .last(n)
  end
end
