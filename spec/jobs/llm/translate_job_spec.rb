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

    context 'when TranslateJob completes successfully' do
      it 'saves bot output as a Message in DB' do
        allow_any_instance_of(described_class).to receive(:llm_translate).and_return(llm_translate_result)

        described_class.perform_now(chat, 'untranslated text', target_language, command_message_from, nil)

        bot_user = User.find_by(is_this_bot: true)
        bot_chat_user = ChatUser.find_by(chat:, user: bot_user)

        expect(Message.last).to have_attributes(
          text: "<#{command_message_from}>\n#{llm_translate_result}",
          chat_user: bot_chat_user
        )
      end
    end
  end
end
