# frozen_string_literal: true

require 'rails_helper'
require 'telegram/bot/updates_controller/rspec_helpers'

# Need to use this lower-level syntax to allow mocks
# https://github.com/telegram-bot-rb/telegram-bot?tab=readme-ov-file#testing
RSpec.describe TelegramWebhooksController, type: :telegram_bot_controller do
  describe 'TelegramWebhooksController::AuthorizationHandler' do
    context 'when a command is sent' do
      context 'when unauthorized' do
        it 'refuses to run commands from other bots' do
          allow_any_instance_of(described_class).to receive(:handle_error).and_raise(
            FuckyWuckies::AuthorizationError
          )

          expect do
            dispatch_command summarize: { from: Telegram::Bot::Types::User.new(
              id: 9999999,
              is_bot: true,
              first_name: 'Botty',
              username: 'tgBotUsername',
              language_code: 'en'
            ) }
          end.to raise_error(FuckyWuckies::AuthorizationError)
        end

        it 'refuses to run commands in non-group chats' do
          allow_any_instance_of(described_class).to receive(:handle_error).and_raise(
            FuckyWuckies::AuthorizationError
          )

          expect do
            dispatch_command summarize: { chat: Telegram::Bot::Types::Chat.new(
              id: 23456,
              type: 'private',
              title: "Someone's DMs"
            ) }
          end.to raise_error(FuckyWuckies::AuthorizationError)

          expect do
            dispatch_command summarize: { chat: Telegram::Bot::Types::Chat.new(
              id: 34567,
              type: 'channel',
              title: 'Some channel'
            ) }
          end.to raise_error(FuckyWuckies::AuthorizationError)
        end

        it 'refuses to run commands in non-whitelisted chats' do
          allow_any_instance_of(described_class).to receive(:handle_error).and_raise(
            FuckyWuckies::AuthorizationError
          )

          expect do
            dispatch_command summarize: { chat: Telegram::Bot::Types::Chat.new(
              id: 23456,
              type: 'group',
              title: 'Some group'
            ) }
          end.to raise_error(FuckyWuckies::AuthorizationError)

          expect do
            dispatch_command summarize: { chat: Telegram::Bot::Types::Chat.new(
              id: 34567,
              type: 'supergroup',
              title: 'Some supergroup'
            ) }
          end.to raise_error(FuckyWuckies::AuthorizationError)
        end
      end
    end
  end
end
