# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::SummarizeUrlJob do
  describe '#perform' do
    let(:chat) { create(:chat) }
    let(:messages) do
      Array.new(10) do
        create(:message, chat:, date: Faker::Time.unique.backward(hours: 1))
      end.sort_by(&:date)
    end

    before do
      allow(LLMTools).to receive(:run_chat_completion).and_return 'LLM generated summary text'

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

    context 'when provided with a custom style' do
      it 'chooses prompt for custom style and injects style properly'
    end

    context 'when NOT provided with a custom style' do
      it 'uses prompt for default neutral style'
    end

    context 'when LLM summarization is successful' do
      it 'sends result message in chat'
      it 'saves bot output as a Message in DB'
    end

    context 'when LLM summarization fails' do
      it 'responds in chat with "LLM error" message'
    end

    context 'when LLM output is blank' do
      it 'responds in chat with "blank output" error'
    end

    context 'when URL loading fails' do
      it 'response in chat with error including HTTP status code'
    end
  end
end
