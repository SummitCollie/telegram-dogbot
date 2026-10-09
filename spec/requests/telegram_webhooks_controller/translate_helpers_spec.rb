# frozen_string_literal: true

require 'rails_helper'
require 'telegram/bot/rspec/integration/rails'
require 'support/telegram_helpers'

RSpec.describe TelegramWebhooksController, telegram_bot: :rails do
  include ActiveJob::TestHelper

  include_context 'with telegram_helpers'

  describe 'TelegramWebhooksController::TranslateHelpers' do
    before do
      Rails.application.credentials.whitelist_enabled = false
    end

    context 'when text is given after the command' do
      it 'leaves picking out a target language to the LLM' do
        chat = create(:chat)
        expect do
          dispatch_command(:translate, 'french hello how are you?', {
                             chat: Telegram::Bot::Types::Chat.new(
                               id: chat.api_id,
                               type: 'supergroup',
                               title: chat.title
                             )
                           })
        end.to have_enqueued_job(LLM::TranslateJob).with(chat, 'french hello how are you?', nil, anything, anything)
      end
    end

    context 'when translate command is a reply to an earlier message' do
      it 'translates text from replied-to message into english by default' do
        chat = create(:chat)
        message_to_translate = Telegram::Bot::Types::Message.new(text: 'text to translate')

        expect do
          dispatch_command(:translate, {
                             chat: Telegram::Bot::Types::Chat.new(
                               id: chat.api_id,
                               type: 'supergroup',
                               title: chat.title
                             ),
                             reply_to_message: message_to_translate
                           })
        end.to have_enqueued_job(LLM::TranslateJob).with(chat, 'text to translate', 'english', anything, anything)
      end

      it 'uses all text after command as target language' do
        chat = create(:chat)
        message_to_translate = Telegram::Bot::Types::Message.new(text: 'text to translate')

        expect do
          dispatch_command(:translate, 'into French', {
                             chat: Telegram::Bot::Types::Chat.new(
                               id: chat.api_id,
                               type: 'supergroup',
                               title: chat.title
                             ),
                             reply_to_message: message_to_translate
                           })
        end.to have_enqueued_job(LLM::TranslateJob).with(chat, 'text to translate', 'into French', anything,
                                                         anything)
      end

      it 'accepts any target language or style' do
        chat = create(:chat)
        message_to_translate = Telegram::Bot::Types::Message.new(text: 'text to translate')

        expect do
          dispatch_command(:translate, 'dog-speak', {
                             chat: Telegram::Bot::Types::Chat.new(
                               id: chat.api_id,
                               type: 'supergroup',
                               title: chat.title
                             ),
                             reply_to_message: message_to_translate
                           })
        end.to have_enqueued_job(LLM::TranslateJob).with(chat, 'text to translate', 'dog-speak', anything,
                                                         anything)
      end
    end

    context 'when not given any text to translate' do
      it 'does not enqueue a TranslateJob' do
        chat = create(:chat)
        expect do
          dispatch_command(:translate, { chat: Telegram::Bot::Types::Chat.new(
            id: chat.api_id,
            type: 'supergroup',
            title: chat.title
          ) })
        end.not_to have_enqueued_job(LLM::TranslateJob)
      end

      it 'outputs help info' do
        chat = create(:chat)
        expect do
          dispatch_command(:translate, { chat: Telegram::Bot::Types::Chat.new(
            id: chat.api_id,
            type: 'supergroup',
            title: chat.title
          ) })
        end.to send_telegram_message(bot, /Choose target language/)
      end
    end
  end
end
