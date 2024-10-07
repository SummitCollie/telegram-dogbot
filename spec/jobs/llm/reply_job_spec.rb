# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::ReplyJob do
  let(:chat) { create(:chat) }
  let(:human) { create(:user) }
  let(:human_cu) { create(:chat_user, chat:, user: human) }

  let(:message_mentioning_bot) do
    create(
      :message,
      chat_user: human_cu,
      text: "hi @#{Rails.application.credentials.telegram.bot.username}",
      date: Time.current
    )
  end

  let(:serialized_msg) do
    TelegramTools.serialize_api_message(
      Telegram::Bot::Types::Message.new(
        message_id: message_mentioning_bot.api_id,
        text: message_mentioning_bot.text,
        date: message_mentioning_bot.date,
        chat: Telegram::Bot::Types::Chat.new(
          id: chat.api_id,
          title: chat.title
        ),
        from: Telegram::Bot::Types::User.new(
          id: message_mentioning_bot.user.api_id,
          is_bot: false,
          first_name: message_mentioning_bot.user.first_name,
          username: message_mentioning_bot.user.username
        )
      )
    )
  end

  # let(:message_replying_to_bot) do
  # end

  # let(:message_replying_to_not_bot) do
  # end

  before do
    allow(LLMTools).to receive(:run_chat_completion).and_return 'LLM generated reply text'

    bot_double = instance_double('Telegram.bot', send_message: true, reset: true)
    allow(Telegram).to receive(:bot).and_return bot_double
  end

  describe '#perform' do
    it 'does not include messages from other chats in prompt' do
      create_list(:message, 3, chat:)
      c1_messages = chat.messages.order(:date)
      
      chat2 = create(:chat)
      c2_messages = create_list(:message, 3, chat: chat2)

      expected_prompt = <<~PROMPT.strip
        ---
        - id: #{c1_messages[0].api_id}
          user: #{c1_messages[0].user.first_name} (@#{c1_messages[0].user.username})
          text: #{c1_messages[0].text}
        - id: #{c1_messages[1].api_id}
          user: #{c1_messages[1].user.first_name} (@#{c1_messages[1].user.username})
          text: #{c1_messages[1].text}
        - id: #{c1_messages[2].api_id}
          user: #{c1_messages[2].user.first_name} (@#{c1_messages[2].user.username})
          text: #{c1_messages[2].text}
        - id: #{message_mentioning_bot.api_id}
          user: #{message_mentioning_bot.user.first_name} (@#{message_mentioning_bot.user.username})
          text: hi @#{Rails.application.credentials.telegram.bot.username}
      PROMPT

      expect(LLMTools).to receive(:run_chat_completion).with(
        model_params: anything,
        system_prompt: anything,
        user_prompt: "#{expected_prompt}\n" # idk why trailing \n is there
      )

      described_class.perform_now(chat, serialized_msg)
    end
  end

  describe '#messages_to_yaml' do
    context 'when message mentioning bot is a reply to another message' do
      context 'when message being replied to is within context' do
        context 'when message being replied to is from this bot' do
          it 'puts `?` in `id` field of bot message' do
            bot_user = create(:user, is_this_bot: true)
            bot_cu = create(:chat_user, chat:, user: bot_user)
            
            bot_message = create(:message, api_id: -1, chat_user: bot_cu)
          end
        end

        context 'when message being replied to is NOT from this bot' do
          it 'puts actual `api_id` value into YAML `id`'
          it 'puts correct `api_id` in YAML `reply_to` of message mentioning bot'
        end
      end

      context 'when message being replied to is NOT within context' do
        it 'copies the message text into context above last message'
      end
    end

    context 'when message mentioning bot is NOT a reply to another message' do
      it 'adds nothing to YAML above user message'
    end

    context 'when LLM output is blank' do
      it 'raises error'
      it 'does not send response message'
    end

    context 'when LLM reply generation successful' do
      it 'sends output in telegram message'
      it 'saves bot output as a Message id DB'
    end
  end
end
