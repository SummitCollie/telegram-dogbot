# frozen_string_literal: true

module LLM
  class ReplyJob < ApplicationJob
    discard_on(FuckyWuckies::ReplyJobFailure) do |_job, error|
      db_chat = error.db_chat
      raise error if db_chat.blank?

      TelegramTools.send_error_message(error, db_chat.api_id)
    end

    def perform(db_chat, message)
      @db_chat = db_chat

      # TODO: need to store all bot replies at send time, and
      # don't forget to filter them out of prompts for other LLM tasks

      messages = db_chat.messages.includes(:user).order(:date).last(100)

      # raise FuckyWuckies::ReplyJobFailure.new(db_chat: @db_chat, frontend_message: 'something')

      # If message.reply_to_message not in context, add it above message in user prompt
    end

    private

    def llm_generate_reply(messages)
      system_prompt = LLMTools.prompt_for_style(:reply_when_mentioned)
      user_prompt = LLMTools.messages_to_yaml(messages)

      output = LLMTools.run_chat_completion(system_prompt:, user_prompt:, model_params: { max_tokens: 128 })

      return unless output.blank?

      raise FuckyWuckies::ReplyJobFailure.new(
        severity: Logger::Severity::ERROR,
        db_chat: @db_chat
      ), "Blank LLM output generating reply to message: " \
          "chat api_id=#{db_chat.id} title=#{db_chat.title}", cause: e
    end

    def send_output_message(text)
      Telegram.bot.send_message(
        chat_id: @db_chat.api_id,
        protect_content: false,
        text:,
        reply_parameters:
      )
      TelegramTools.store_bot_output(@db_chat, text, reply_to: )
    end
  end
end
