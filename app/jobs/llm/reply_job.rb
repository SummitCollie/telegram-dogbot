# frozen_string_literal: true

module LLM
  class ReplyJob < ApplicationJob
    retry_on FuckyWuckies::ReplyJobError
    rescue_from FuckyWuckies::ReplyJobFailure, with: :handle_error

    def perform(db_chat, message)
      # TODO: need to store all bot replies at send time, and
      # don't forget to filter them out of prompts for other LLM tasks

      messages = db_chat&.messages.order(:date).last(100).includes(:user)

      # TODO: maybe use yaml after all?
      csv_messages = "id,reply to,time,username,alias,text\n"
      messages.each do |message|
        csv_messages << ""
      end

      # If message.reply_to_message not in context, add it above message in user prompt
    end

    private

    def send_output_message(db_chat, text)
      Telegram.bot.send_message(
        chat_id: db_chat.api_id,
        protect_content: false,
        text:
      )
    end

    def handle_error
      db_chat = error.db_chat
      raise error if db_chat.blank?

      # Respond in chat with error message
      TelegramTools.send_error_message(error, db_chat.api_id)
    end
  end
end
