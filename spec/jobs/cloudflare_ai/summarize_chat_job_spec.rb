# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CloudflareAi::SummarizeChatJob do
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
          :cloudflare_summarize
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

      context 'when previous summary of same type exists' do
        it 'attempts to summarize all messages since last summary' do
          summary_time = messages[49].date
          summary = create(:chat_summary, chat:, created_at: summary_time)
          expected_messages = messages.drop(50)

          expect_any_instance_of(described_class).to receive(
            :cloudflare_summarize
          ).with(expected_messages, summary.summary_type)

          described_class.perform_now(summary)
        end
      end

      context 'when no previous summary of same type exists' do
        it 'attempts to summarize last 200 messages' do
          summary = create(:chat_summary, chat:)
          expected_messages = messages.drop(50)

          expect_any_instance_of(described_class).to receive(
            :cloudflare_summarize
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
        allow_any_instance_of(described_class).to receive(:cloudflare_summarize)

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
          :cloudflare_summarize
        ).with(expected_messages, summary.summary_type)

        described_class.perform_now(summary)
      end

      it 'uses 50% fewer messages on attempt 3' do
        allow_any_instance_of(described_class).to receive(:executions).and_return(3)
        expected_messages = messages.drop(50)

        expect_any_instance_of(described_class).to receive(
          :cloudflare_summarize
        ).with(expected_messages, summary.summary_type)

        described_class.perform_now(summary)
      end

      it 'uses 75% fewer messages on attempt 4' do
        allow_any_instance_of(described_class).to receive(:executions).and_return(4)
        expected_messages = messages.drop(75)

        expect_any_instance_of(described_class).to receive(
          :cloudflare_summarize
        ).with(expected_messages, summary.summary_type)

        described_class.perform_now(summary)
      end
    end

    context 'when maximum attempts reached' do
      before do
        allow_any_instance_of(described_class).to receive(:cloudflare_summarize)
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
      it 'correctly updates existing ChatSummary record with results'
      it 'sends message to chat containing summarize result'
    end
  end
end
