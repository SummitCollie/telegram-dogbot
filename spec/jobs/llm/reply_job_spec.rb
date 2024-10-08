# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::ReplyJob do
  let(:chat) { create(:chat) }
  let(:human) { create(:user) }
  let(:human_cu) { create(:chat_user, chat:, user: human) }
  let(:bot) { create(:user, is_this_bot: true) }
  let(:bot_cu) { create(:chat_user, chat:, user: bot) }

  let(:bot_message) { create(:message, chat_user: bot_cu, text: 'bot msg text', date: 1.minute.ago) }
  let(:api_bot_msg) do
    Telegram::Bot::Types::Message.new(
      message_id: bot_message.api_id,
      text: bot_message.text,
      date: bot_message.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: bot.api_id,
        is_bot: true,
        first_name: bot.first_name,
        username: bot.username
      )
    )
  end

  let(:human_message) { create(:message, chat_user: human_cu, text: 'reply to bot text', date: Time.current) }
  let(:api_human_msg) do
    Telegram::Bot::Types::Message.new(
      message_id: human_message.api_id,
      text: human_message.text,
      date: human_message.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: human.api_id,
        is_bot: false,
        first_name: human.first_name,
        username: human.username
      )
    )
  end

  let(:other_human_message) { create(:message, chat:, text: 'text from random user', date: 1.minute.ago) }

  let(:api_other_human_msg) do
    Telegram::Bot::Types::Message.new(
      message_id: other_human_message.api_id,
      text: other_human_message.text,
      date: other_human_message.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: other_human_message.user.api_id,
        is_bot: false,
        first_name: other_human_message.user.first_name,
        username: other_human_message.user.username
      )
    )
  end

  let(:old_human_message) { create(:message, chat:, text: 'old message text', date: 3.days.ago) }

  let(:api_old_human_message) do
    Telegram::Bot::Types::Message.new(
      message_id: old_human_message.api_id,
      text: old_human_message.text,
      date: old_human_message.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: old_human_message.user.api_id,
        is_bot: false,
        first_name: old_human_message.user.first_name,
        username: old_human_message.user.username
      )
    )
  end

  let(:bot_mention) do
    create(
      :message,
      chat_user: human_cu,
      text: "hi @#{Rails.application.credentials.telegram.bot.username}",
      date: Time.current
    )
  end

  let(:api_bot_mention) do
    Telegram::Bot::Types::Message.new(
      message_id: bot_mention.api_id,
      text: bot_mention.text,
      date: bot_mention.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: human.api_id,
        is_bot: false,
        first_name: human.first_name,
        username: human.username
      )
    )
  end

  let(:reply_to_bot) do
    create(:message, chat_user: human_cu,
                     text: 'text in msg replying to a bot msg',
                     date: Time.current,
                     reply_to_message: bot_message)
  end

  let(:api_reply_to_bot) do
    Telegram::Bot::Types::Message.new(
      message_id: reply_to_bot.api_id,
      text: reply_to_bot.text,
      date: reply_to_bot.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: human.api_id,
        is_bot: false,
        first_name: human.first_name,
        username: human.username
      ),
      reply_to_message: api_bot_msg
    )
  end

  let(:reply_to_human) do
    create(:message, chat_user: human_cu,
                     text: 'text in msg replying to a random user msg',
                     date: Time.current,
                     reply_to_message: other_human_message)
  end

  let(:api_reply_to_human) do
    Telegram::Bot::Types::Message.new(
      message_id: reply_to_human.api_id,
      text: reply_to_human.text,
      date: reply_to_human.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: human.api_id,
        is_bot: false,
        first_name: human.first_name,
        username: human.username
      ),
      reply_to_message: api_other_human_msg
    )
  end

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
      create_list(:message, 3, chat: chat2)

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
        - id: #{bot_mention.api_id}
          user: #{human.first_name} (@#{human.username})
          text: hi @#{bot.username}
      PROMPT

      described_class.perform_now(chat, TelegramTools.serialize_api_message(api_bot_mention))

      expect(LLMTools).to have_received(:run_chat_completion).with(
        model_params: anything,
        system_prompt: anything,
        user_prompt: expected_prompt
      )
    end
  end

  describe '#messages_to_yaml' do
    context 'when message mentioning bot is a reply to another message' do
      context 'when message being replied to is within context' do
        it 'does not copy reply_to_message into context' do
          intermediate_msg = create(
            :message,
            chat_user: human_cu,
            text: 'intermediate msg text',
            date: other_human_message.date + 1.second
          )

          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

          expected_prompt = <<~PROMPT.strip
            ---
            - id: #{other_human_message.api_id}
              user: #{other_human_message.user.first_name} (@#{other_human_message.user.username})
              text: #{other_human_message.text}
            - id: #{intermediate_msg.api_id}
              user: #{intermediate_msg.user.first_name} (@#{intermediate_msg.user.username})
              text: #{intermediate_msg.text}
            - id: #{reply_to_human.api_id}
              user: #{human.first_name} (@#{human.username})
              text: #{reply_to_human.text}
              reply_to: #{other_human_message.api_id}
          PROMPT

          expect(LLMTools).to have_received(:run_chat_completion).with(
            model_params: anything,
            system_prompt: anything,
            user_prompt: expected_prompt
          )
        end
      end

      context 'when message being replied to is NOT within context' do
        it 'copies reply_to_message into context above last message' do
          reply_to_human.update!(reply_to_message: old_human_message)
          api_reply_to_human = Telegram::Bot::Types::Message.new(
            message_id: reply_to_human.api_id,
            text: reply_to_human.text,
            date: reply_to_human.date,
            chat: Telegram::Bot::Types::Chat.new(
              id: chat.api_id,
              title: chat.title
            ),
            from: Telegram::Bot::Types::User.new(
              id: human.api_id,
              is_bot: false,
              first_name: human.first_name,
              username: human.username
            ),
            reply_to_message: api_old_human_message
          )

          create_list(:message, 100,
                      chat_user: human_cu,
                      text: 'intermediate msg text',
                      date: other_human_message.date + 1.second)

          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

          expect(LLMTools).to have_received(:run_chat_completion) do |args|
            results = YAML.parse(args[:user_prompt]).children[0].to_ruby

            expect(results.count do |r|
              r['id'] == old_human_message.api_id
            end).to eq 1

            expect(results[-2]).to include(
              'id' => old_human_message.api_id,
              'user' => "#{old_human_message.user.first_name} (@#{old_human_message.user.username})",
              'text' => old_human_message.text
            )
          end
        end
      end

      context 'when message being replied to is from this bot' do
        it 'puts `?` in `id` field of bot message YAML' do
          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_bot))

          expected_prompt = <<~PROMPT.strip
            ---
            - id: "?"
              user: #{bot.first_name} (@#{bot.username})
              text: #{bot_message.text}
            - id: #{reply_to_bot.api_id}
              user: #{human.first_name} (@#{human.username})
              text: #{reply_to_bot.text}
              reply_to: #{api_reply_to_bot.reply_to_message.message_id}
          PROMPT

          expect(LLMTools).to have_received(:run_chat_completion).with(
            model_params: anything,
            system_prompt: anything,
            user_prompt: expected_prompt
          )
        end
      end

      context 'when message being replied to is NOT from this bot' do
        it 'puts actual `api_id` value into YAML `id` & `reply_to`'
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
