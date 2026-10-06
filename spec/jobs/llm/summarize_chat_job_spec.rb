# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::SummarizeChatJob do
  describe '#perform' do
    context 'when cancelled from the progress message' do
      let(:chat) { create(:chat) }
      let!(:summary) { create(:chat_summary, chat:, summary_type: :default, status: :running) }

      before do
        create(:message, chat:)
        allow_any_instance_of(described_class).to receive(:llm_summarize).and_raise LLMProgress::Cancelled
      end

      it 'deletes the running summary (so another can be started), sending nothing' do
        expect_any_instance_of(described_class).not_to receive(:send_output_message)

        expect { described_class.perform_now(summary) }.not_to raise_error
        expect(ChatSummary.exists?(summary.id)).to be false
      end
    end

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
        ).with(messages, chat1_summary.summary_type, an_instance_of(LLMProgress))

        described_class.perform_now(chat1_summary)
      end

      context 'when previous summary of same type exists' do
        it 'attempts to summarize all messages since last summary' do
          summary_time = messages[49].date
          summary = create(:chat_summary, chat:, created_at: summary_time)
          expected_messages = messages.drop(50)

          expect_any_instance_of(described_class).to receive(
            :llm_summarize
          ).with(expected_messages, summary.summary_type, an_instance_of(LLMProgress))

          described_class.perform_now(summary)
        end
      end

      context 'when no previous summary of same type exists' do
        it 'attempts to summarize last 200 messages' do
          summary = create(:chat_summary, chat:)
          expected_messages = messages.drop(50)

          expect_any_instance_of(described_class).to receive(
            :llm_summarize
          ).with(expected_messages, summary.summary_type, an_instance_of(LLMProgress))

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
        ).with(expected_messages, summary.summary_type, an_instance_of(LLMProgress))

        described_class.perform_now(summary)
      end

      it 'uses 50% fewer messages on attempt 3' do
        allow_any_instance_of(described_class).to receive(:executions).and_return(3)
        expected_messages = messages.drop(50)

        expect_any_instance_of(described_class).to receive(
          :llm_summarize
        ).with(expected_messages, summary.summary_type, an_instance_of(LLMProgress))

        described_class.perform_now(summary)
      end

      it 'uses 75% fewer messages on attempt 4' do
        allow_any_instance_of(described_class).to receive(:executions).and_return(4)
        expected_messages = messages.drop(75)

        expect_any_instance_of(described_class).to receive(
          :llm_summarize
        ).with(expected_messages, summary.summary_type, an_instance_of(LLMProgress))

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
      let(:chat) { create(:chat) }

      before do
        allow(LLMTools).to receive(:prompt_completion).and_return 'LLM output'
        create_list(:message, 10, chat:, date: Faker::Time.unique.backward(days: 1))
      end

      it 'chooses prompt for custom style and injects style properly' do
        style = 'as a love letter'
        summary = create(:chat_summary, chat:, summary_type: :custom, style:)

        expected_system_prompt = <<~PROMPT.strip
          SUMMARY_STYLE=#{style}
          Summarize the group chat messages in the specified SUMMARY_STYLE.
          Only provide the summary text to send in response message: no formatting, no preface.
        PROMPT

        described_class.perform_now(summary)

        expect(LLMTools).to have_received(:prompt_completion).with(
          system_prompt: expected_system_prompt,
          progress: an_instance_of(LLMProgress),
          user_prompt: anything
        )
      end
    end

    context 'when NOT provided with a custom style' do
      let(:chat) { create(:chat) }

      before do
        allow(LLMTools).to receive(:prompt_completion).and_return 'LLM output'
        create_list(:message, 10, chat:, date: Faker::Time.unique.backward(days: 1))
      end

      it 'uses prompt for default neutral style' do
        summary = create(:chat_summary, chat:, summary_type: :default, style: nil)
        expected_system_prompt = File.read('data/llm_prompts/summarize.txt')

        described_class.perform_now(summary)

        expect(LLMTools).to have_received(:prompt_completion).with(
          system_prompt: expected_system_prompt,
          progress: an_instance_of(LLMProgress),
          user_prompt: anything
        )
      end
    end
  end

  describe '.chat_log' do
    def chat_log_lines(messages) = described_class.chat_log(messages).lines(chomp: true)

    it 'has one line per message with id, first name and text' do
      chat = create(:chat)
      messages = Array.new(250) do
        create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
      end.sort_by(&:date)

      lines = chat_log_lines(messages)

      expect(lines.size).to eq messages.size
      expect(lines.first).to eq "##{messages.first.api_id} #{messages.first.user.first_name}: #{messages.first.text}"
      expect(lines.last).to eq "##{messages.last.api_id} #{messages.last.user.first_name}: #{messages.last.text}"
    end

    it 'sets `replying to` for messages replying to this bot' do
      chat = create(:chat)
      bot_cu = create(:chat_user, chat:, user: create(:user, is_this_bot: true))
      bot_message = create(:message, chat_user: bot_cu, date: 2.minutes.ago)
      reply_to_bot = create(:message, chat:, date: 1.minute.ago, reply_to_message: bot_message)

      lines = chat_log_lines([bot_message, reply_to_bot])

      expect(lines.first).to start_with "##{bot_message.api_id} "
      expect(lines.last).to include " replying to ##{bot_message.api_id}: "
    end

    it 'sets `replying to` when parent message within context' do
      chat = create(:chat)
      parent_message = create(:message, chat:, date: 2.minutes.ago)
      response_message = create(:message, chat:, date: 1.minute.ago, reply_to_message: parent_message)

      expect(chat_log_lines([parent_message, response_message]).last)
        .to include " replying to ##{parent_message.api_id}: "
    end

    it 'omits `replying to` when parent message outside context' do
      chat = create(:chat)
      parent_message = create(:message, chat:, date: 3.minutes.ago)
      response_message = create(:message, chat:, date: 2.minutes.ago, reply_to_message: parent_message)

      expect(chat_log_lines([response_message]).last).not_to include 'replying to'
    end

    it 'shows attachment type only for messages with attachments' do
      chat = create(:chat)
      message_w_photo = create(:message, chat:, date: 2.hours.ago, attachment_type: :photo)
      message_no_photo = create(:message, chat:, date: 1.hour.ago)

      lines = chat_log_lines([message_w_photo, message_no_photo])

      expect(lines.first).to start_with "##{message_w_photo.api_id} #{message_w_photo.user.first_name} [photo]: "
      expect(lines.last).not_to include '['
    end
  end
end
