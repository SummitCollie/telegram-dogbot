# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::ReplyJob do
  describe '#perform' do
    it 'does not include messages from other chats in prompt'
  end

  describe '#messages_to_yaml' do
    context 'when user replies to a message with unknown api_id (from this bot)'
    context 'when user replies to a message with known api_id (not from this bot)'
  end
end
