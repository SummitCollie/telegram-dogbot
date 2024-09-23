# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::TranslateJob do
  describe '#perform' do
    let(:chat) { create(:chat) }
    let(:text_to_translate) { 'the text to translate' }
    let(:target_language) { 'spanish' }
    let(:command_message_from) { 'UserWhoSentCommand' }
    let(:parent_message_from) { 'UserWhoSentMessageWhichCommandIsReplyingTo' }
    let(:llm_translate_result) { 'translated text' }

    before do
      allow_any_instance_of(described_class).to receive(:llm_translate).and_return(llm_translate_result)
    end

    context 'when not provided a target language' do
      it 'defaults to english' do
        expect_any_instance_of(described_class).to receive(:llm_translate).with(text_to_translate, 'english')
        described_class.perform_now(chat, text_to_translate, nil, command_message_from, nil)
      end
    end
  end
end
