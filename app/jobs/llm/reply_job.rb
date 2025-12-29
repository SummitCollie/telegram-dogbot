# frozen_string_literal: true

module LLM
  class ReplyJob < ApplicationJob
    discard_on(FuckyWuckies::ReplyJobFailure) do |_job, error|
      raise error
    end

    def perform(db_chat, serialized_message)
      @db_chat = db_chat
      api_message = TelegramTools.deserialize_api_message(serialized_message)
      db_message = @db_chat.messages.find_by(api_id: api_message.message_id)

      # Messages sent before bot was mentioned
      past_db_messages = @db_chat.messages.includes(:user, :reply_to_message)
                                 .where(date: ...db_message.date)
                                 .references(:user, :message)
                                 .order(:date)
                                 .last(100)

      # Message which mentioned the bot, optionally preceded by `message.reply_to_message`
      # (if the reply_to_message doesn't already exist within the context of past_db_messages)
      last_api_messages = get_last_messages(past_db_messages, api_message)

      result_text = llm_generate_reply(past_db_messages, last_api_messages)
      if result_text.blank?
        raise FuckyWuckies::ReplyJobFailure.new,
              "Blank output when generating reply to message_id=#{db_message.id}"
      end

      send_output_message(result_text, reply_to: db_message)
    rescue Faraday::Error => e
      raise FuckyWuckies::ReplyJobFailure.new(
        severity: Logger::Severity::ERROR,
        db_chat: @db_chat
      ), 'Error generating reply to message: ' \
         "chat api_id=#{db_chat.id} title=#{db_chat.title}", cause: e
    end

    # api_messages are added at the very end of the output
    def messages_to_yaml(db_messages, api_messages = [])
      outputs = [
        *db_messages.map { |m| db_message_to_yaml(db_messages, m) },
        *api_messages.map { |m| api_message_to_yaml(m) }
      ]

      # avoids ':' prefix on every key in the resulting YAML
      # https://stackoverflow.com/a/53093339
      outputs.each(&:deep_stringify_keys!)

      outputs.to_yaml({ line_width: -1 }) # Don't wrap long lines
    end

    private

    def llm_generate_reply(past_db_messages, last_api_messages)
      system_prompt = "#{LLMTools.prompt_for_mode(:reply_when_mentioned)}\n" \
                      "Chatroom title: #{@db_chat.title}"
      user_prompt = messages_to_yaml(past_db_messages, last_api_messages).strip

      TelegramTools.logger.debug("\n##### Reply to message:\n" \
                                 "### System prompt:\n#{system_prompt}\n" \
                                 "### User prompt:\n#{user_prompt}")

      output = LLMTools.run_chat_completion(system_prompt:, user_prompt:)

      if output.blank?
        raise FuckyWuckies::ReplyJobFailure.new(
          severity: Logger::Severity::ERROR,
          db_chat: @db_chat
        ), 'Blank LLM output generating reply to message: ' \
           "chat api_id=#{@db_chat.id} title=#{@db_chat.title}"
      end

      output
    end

    # Since we can't know the telegram message_ids of messages sent by this bot,
    # need extra logic to test whether `message.reply_to_message` already exists
    # within context and therefore shouldn't be added to the prompt again.
    def get_last_messages(past_db_messages, api_message)
      reply_to_message = api_message&.reply_to_message
      return [api_message] if reply_to_message.blank?

      reply_to_message_date = Time.zone.at(reply_to_message.date).to_datetime
      return [api_message] if past_db_messages.first.date.floor <= reply_to_message_date

      # reply_to_message not in context, so add it above the user's message
      [reply_to_message, api_message]
    end

    def db_message_to_yaml(db_messages, message)
      yaml = {
        id: message.api_id == -1 ? '?' : message.api_id,
        user: "#{message.user.first_name} (@#{message.user.username})",
        text: message.text
      }

      yaml[:attachment] = message.attachment_type.to_s if message.attachment_type.present?
      yaml[:reply_to] = message.reply_to_message.api_id if db_messages.include?(message.reply_to_message)
      yaml
    end

    def api_message_to_yaml(message)
      yaml = {
        id: message.message_id == -1 ? '?' : message.message_id,
        user: "#{message.from.first_name} (@#{message.from.username})",
        text: message.text
      }

      attachment_type = TelegramTools.attachment_type(message)
      yaml[:attachment] = attachment_type if attachment_type
      yaml[:reply_to] = message.reply_to_message.message_id if message.reply_to_message.present?
      yaml
    end

    def send_output_message(text, reply_to:)
      Telegram.bot.send_message(
        chat_id: @db_chat.api_id,
        protect_content: false,
        text:,
        reply_parameters: {
          message_id: reply_to.api_id,
          allow_sending_without_reply: true
        }
      )
      TelegramTools.store_bot_output(@db_chat, text, reply_to:)
    end
  end
end
