# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat do
  describe '#messages_since_last_summary' do
    context 'when a previous summary of the same type exists' do
      it 'returns messages sent since the last summary'

      it 'does not return messages from other chats'
    end

    context 'when no previous summary of the same type exists' do
      it 'just returns up to the last 200 messages'

      it 'does not return messages from other chats'
    end
  end
end
