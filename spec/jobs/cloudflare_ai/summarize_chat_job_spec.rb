# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CloudflareAi::SummarizeChatJob do
  describe '#perform' do
    context 'when running first attempt' do
      it 'attempts to summarize all messages since last summary of same type'
    end

    context 'when first attempt fails' do
      it 'attempts to summarize with 25% fewer messages on subsequent attempts'
    end

    context 'when maximum attempts reached' do
      it 'deletes ChatSummary record'
      it 'responds with a failure message'
    end

    context 'when a SummarizeChatJob completes successfully' do
      it 'updates existing ChatSummary record with result'
    end
  end
end
