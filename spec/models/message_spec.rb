# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message do
  describe '#stub_api_id_for_own_messages' do
    context 'when saving a message sent by this bot' do
      it 'stubs api_id as -1' do
        chat = create(:chat)
        bot_user = create(:user, is_this_bot: true)
        bot_chat_user = create(:chat_user, chat:, user: bot_user)

        message = create(:message, chat_user: bot_chat_user)

        expect(message.api_id).to eq(-1)
      end
    end

    context 'when saving a message NOT sent by this bot' do
      it 'does not stub api_id as -1' do
        chat = create(:chat)
        user = create(:user)
        chat_user = create(:chat_user, chat:, user:)

        message = create(:message, chat_user:)

        expect(message.api_id).not_to eq(-1)
      end
    end
  end
end
