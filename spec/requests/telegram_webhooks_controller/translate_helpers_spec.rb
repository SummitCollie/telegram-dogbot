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

    context 'when a target language is specified' do
      it 'excludes language choice (first word after command) from translated text' do
        chat = create(:chat)
        expect do
          dispatch_command(:translate, 'french hello how are you?', {
                             chat: Telegram::Bot::Types::Chat.new(
                               id: chat.api_id,
                               type: 'supergroup',
                               title: chat.title
                             )
                           })
        end.to have_enqueued_job(LLM::TranslateJob).with(chat, 'hello how are you?', 'french', anything, anything)
      end

      it 'detects target language regardless of capitalization' do
        chat = create(:chat)
        expect do
          dispatch_command(:translate, 'FrEncH hello how are you?', {
                             chat: Telegram::Bot::Types::Chat.new(
                               id: chat.api_id,
                               type: 'supergroup',
                               title: chat.title
                             )
                           })
        end.to have_enqueued_job(LLM::TranslateJob).with(chat, 'hello how are you?', 'french', anything, anything)
      end
    end

    context 'when a target language is NOT specified' do
      it 'leaves first word of input in translated text' do
        chat = create(:chat)
        expect do
          dispatch_command(:translate, 'hola mi amigo', {
                             chat: Telegram::Bot::Types::Chat.new(
                               id: chat.api_id,
                               type: 'supergroup',
                               title: chat.title
                             )
                           })
        end.to have_enqueued_job(LLM::TranslateJob).with(chat, 'hola mi amigo', nil, anything, anything)
      end
    end

    context 'when translate command is a reply to an earlier message' do
      it 'translates text from replied-to message' do
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
        end.to have_enqueued_job(LLM::TranslateJob).with(chat, 'text to translate', nil, anything, anything)
      end

      it 'still searches for target language after command' do
        chat = create(:chat)
        message_to_translate = Telegram::Bot::Types::Message.new(text: 'text to translate')

        expect do
          dispatch_command(:translate, 'french', {
                             chat: Telegram::Bot::Types::Chat.new(
                               id: chat.api_id,
                               type: 'supergroup',
                               title: chat.title
                             ),
                             reply_to_message: message_to_translate
                           })
        end.to have_enqueued_job(LLM::TranslateJob).with(chat, 'text to translate', 'french', anything, anything)
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
        end.to send_telegram_message(bot, /Supported languages/)
      end
    end
  end
end
