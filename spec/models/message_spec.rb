# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message do
  describe '#stub_api_id_for_own_messages' do
    let(:chat) { create(:chat) }

    context 'when saving a message sent by this bot' do
      let(:bot_chat_user) { create(:chat_user, chat:, user: create(:user, is_this_bot: true)) }

      it 'keeps api_id if known' do
        message = create(:message, chat_user: bot_chat_user, api_id: 12345)

        expect(message.api_id).to eq 12345
      end

      it 'stubs api_id as -1 if unknown' do
        message = create(:message, chat_user: bot_chat_user, api_id: nil)

        expect(message.api_id).to eq(-1)
      end
    end

    context 'when saving a message NOT sent by this bot' do
      it 'does not stub api_id as -1' do
        message = create(:message, chat_user: create(:chat_user, chat:))

        expect(message.api_id).not_to eq(-1)
      end
    end
  end
end
