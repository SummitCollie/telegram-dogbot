# frozen_string_literal: true

require 'rails_helper'
require 'telegram/bot/rspec/integration/rails'
require 'telegram/bot/rspec/callback_query_helpers'

RSpec.describe TelegramWebhooksController, telegram_bot: :rails do
  describe '#callback_query' do
    include_context 'telegram/bot/callback_query'

    let(:chat_id) { -100123 }
    let(:from) { { id: 4242, is_bot: false, first_name: 'Presser', username: 'presser' } }

    before { allow(LLMProgress).to receive(:cancel).and_return 'Cancelled' }

    context 'with the progress message cancel button' do
      let(:data) { LLMProgress::CANCEL_DATA }

      it 'cancels the progress message it was pressed on, answering with the result' do
        expect { dispatch callback_query: payload }.to answer_callback_query('Cancelled')

        expect(LLMProgress).to have_received(:cancel)
          .with(chat_api_id: chat_id, message_id:, from: having_attributes(id: 4242, username: 'presser'))
      end
    end

    context 'with any other button' do
      let(:data) { 'something else' }

      it 'ignores it' do
        expect { dispatch callback_query: payload }.to answer_callback_query('?')

        expect(LLMProgress).not_to have_received(:cancel)
      end
    end
  end
end
