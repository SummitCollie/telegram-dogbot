# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::SummarizeChatJob do
  describe '#perform' do
    context 'when running first attempt' do
      let(:chat) { create(:chat) }
      let(:messages) do
        Array.new(250) do
          create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
        end.sort_by(&:date)
      end

      before do
        allow_any_instance_of(described_class).to receive(
          :llm_summarize
        ).and_return('summary text')

        allow_any_instance_of(described_class).to receive(
          :send_output_message
        ).and_return({
          ok: true,
          result: {
            chat_id: chat.api_id,
            protect_content: true,
            text: 'summary text'
          }
        }.to_json)
      end

      it 'does not include messages from other chats' do
        chat2 = create(:chat)
        create_list(:message, 100, chat: chat2, date: Faker::Time.unique.backward(days: 0.5))

        # First create an old ChatSummary so all messages since then are selected
        create(:chat_summary, chat:, summary_type: :vibe_check, status: :complete, created_at: 5.days.ago)
        chat1_summary = create(:chat_summary, chat:, summary_type: :vibe_check, status: :running,
                                              created_at: Time.current)

        expect_any_instance_of(described_class).to receive(
          :llm_summarize
        ).with(messages, chat1_summary.summary_type)

        described_class.perform_now(chat1_summary)
      end

      context 'when previous summary of same type exists' do
        it 'attempts to summarize all messages since last summary' do
          summary_time = messages[49].date
          summary = create(:chat_summary, chat:, created_at: summary_time)
          expected_messages = messages.drop(50)

          expect_any_instance_of(described_class).to receive(
            :llm_summarize
          ).with(expected_messages, summary.summary_type)

          described_class.perform_now(summary)
        end
      end

      context 'when no previous summary of same type exists' do
        it 'attempts to summarize last 200 messages' do
          summary = create(:chat_summary, chat:)
          expected_messages = messages.drop(50)

          expect_any_instance_of(described_class).to receive(
            :llm_summarize
          ).with(expected_messages, summary.summary_type)

          described_class.perform_now(summary)
        end
      end
    end

    context 'when first attempt fails' do
      let(:chat) { create(:chat) }
      let(:summary) { create(:chat_summary, chat:) }
      let(:messages) do
        Array.new(100) do
          create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
        end.sort_by(&:date)
      end

      before do
        allow_any_instance_of(described_class).to receive(:llm_summarize)

        allow_any_instance_of(described_class).to receive(
          :send_output_message
        ).and_return({
          ok: true,
          result: {
            chat_id: chat.api_id,
            protect_content: true,
            text: 'summary text'
          }
        }.to_json)
      end

      it 'uses 25% fewer messages on attempt 2' do
        allow_any_instance_of(described_class).to receive(:executions).and_return(2)
        expected_messages = messages.drop(25)

        expect_any_instance_of(described_class).to receive(
          :llm_summarize
        ).with(expected_messages, summary.summary_type)

        described_class.perform_now(summary)
      end

      it 'uses 50% fewer messages on attempt 3' do
        allow_any_instance_of(described_class).to receive(:executions).and_return(3)
        expected_messages = messages.drop(50)

        expect_any_instance_of(described_class).to receive(
          :llm_summarize
        ).with(expected_messages, summary.summary_type)

        described_class.perform_now(summary)
      end

      it 'uses 75% fewer messages on attempt 4' do
        allow_any_instance_of(described_class).to receive(:executions).and_return(4)
        expected_messages = messages.drop(75)

        expect_any_instance_of(described_class).to receive(
          :llm_summarize
        ).with(expected_messages, summary.summary_type)

        described_class.perform_now(summary)
      end
    end

    context 'when maximum attempts reached' do
      before do
        allow_any_instance_of(described_class).to receive(:llm_summarize).and_return('summary text')
        allow_any_instance_of(described_class).to receive(:executions).and_return(5)
      end

      it 'raises fatal error and deletes in-progress ChatSummary' do
        chat = create(:chat)
        summary = create(:chat_summary, chat:)
        Array.new(100) do
          create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
        end

        expect do
          described_class.new.perform(summary)
        end.to raise_error(FuckyWuckies::SummarizeJobFailure) and change(ChatSummary, :count).by(-1)
      end
    end

    context 'when a SummarizeChatJob completes successfully' do
      it 'sends summary text' do
        chat = create(:chat)
        summary = create(:chat_summary, chat:)
        Array.new(100) do
          create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
        end

        allow_any_instance_of(described_class).to receive(:llm_summarize).and_return('summary text')
        expect_any_instance_of(described_class).to receive(:send_output_message).with('summary text')

        described_class.perform_now(summary)
      end

      it 'saves LLM output text on ChatSummary in DB' do
        allow_any_instance_of(described_class).to receive(:llm_summarize).and_return('summary text')

        chat = create(:chat)
        summary = create(:chat_summary, chat:)
        Array.new(100) do
          create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
        end

        described_class.perform_now(summary)

        expect(summary.reload.text).to eq 'summary text'
      end

      it 'saves bot output as a Message in DB' do
        allow_any_instance_of(described_class).to receive(:llm_summarize).and_return('summary text')

        chat = create(:chat)
        summary = create(:chat_summary, chat:)
        Array.new(100) do
          create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
        end

        described_class.perform_now(summary)

        bot_user = User.find_by(is_this_bot: true)
        bot_chat_user = ChatUser.find_by(chat:, user: bot_user)

        expect(Message.last).to have_attributes(
          text: 'summary text',
          chat_user: bot_chat_user
        )
      end
    end

    context 'when provided with a custom style' do
      it 'chooses prompt for custom style and injects it properly'
    end

    context 'when NOT provided with a custom style' do
      it 'uses prompt for default neutral style'
    end
  end

  describe '.messages_to_yaml' do
    it 'contains all input messages' do
      chat = create(:chat)
      messages = Array.new(250) do
        create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
      end.sort_by(&:date)

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.size).to eq messages.size
    end

    it 'correctly sets id/user/text' do
      chat = create(:chat)
      messages = Array.new(250) do
        create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
      end.sort_by(&:date)

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.first['id']).to eq messages.first.api_id
      expect(results.first['user']).to eq messages.first.user.first_name
      expect(results.first['text']).to eq messages.first.text

      expect(results.last['id']).to eq messages.last.api_id
      expect(results.last['user']).to eq messages.last.user.first_name
      expect(results.last['text']).to eq messages.last.text
    end

    it 'sets `id` to `?` for messages sent by this bot' do
      chat = create(:chat)
      bot_user = create(:user, is_this_bot: true)
      bot_cu = create(:chat_user, chat:, user: bot_user)
      messages = [create(:message, chat_user: bot_cu, date: 2.minutes.ago)]

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.first['id']).to eq '?'
    end

    it 'sets `reply_to` to parent message ID when parent message within context' do
      chat = create(:chat)
      parent_message = create(:message, chat:, date: 2.minutes.ago)
      response_message = create(:message, chat:, date: 1.minute.ago, reply_to_message: parent_message)
      messages = [parent_message, response_message]

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.last['reply_to']).to eq messages.first.api_id
    end

    it 'omits `reply_to` when parent message outside context' do
      chat = create(:chat)
      parent_message = create(:message, chat:, date: 3.minutes.ago)
      response_message = create(:message, chat:, date: 2.minutes.ago, reply_to_message: parent_message)
      create(:message, chat:, date: 1.minute.ago)
      messages = [response_message]

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.last.key?('reply_to')).to be false
    end

    it 'omits `reply_to` when parent message was sent by this bot' do
      # because we don't know the ID of outgoing messages, so can't match against them
      chat = create(:chat)
      bot_user = create(:user, is_this_bot: true)
      bot_cu = create(:chat_user, chat:, user: bot_user)

      parent_message = create(:message, chat_user: bot_cu, date: 2.minutes.ago)
      response_message = create(:message, chat:, date: 1.minute.ago, reply_to_message: parent_message)
      messages = [parent_message, response_message]

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.last.key?('reply_to')).to be false
    end

    it 'sets `attachment_type` for messages with attachments' do
      chat = create(:chat)
      message_w_photo = create(:message, chat:, date: 2.hours.ago, attachment_type: :photo)
      message_no_photo = create(:message, chat:, date: 1.hour.ago)
      messages = [message_w_photo, message_no_photo]

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.first['attachment']).to eq 'photo'
    end

    it 'omits `attachment_type` for messages without attachments' do
      chat = create(:chat)
      message_w_photo = create(:message, chat:, date: 2.hours.ago, attachment_type: :photo)
      message_no_photo = create(:message, chat:, date: 1.hour.ago)
      messages = [message_w_photo, message_no_photo]

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.last.key?('attachment')).to be false
    end
  end
end
