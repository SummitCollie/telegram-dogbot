# frozen_string_literal: true

require 'rails_helper'
require 'support/telegram_helpers'
require 'telegram/bot/updates_controller/rspec_helpers'

# Need to use this lower-level syntax to allow mocks
# https://github.com/telegram-bot-rb/telegram-bot?tab=readme-ov-file#testing
RSpec.describe TelegramWebhooksController, type: :telegram_bot_controller do
  include_context 'with telegram_helpers'

  describe 'TelegramWebhooksController::AuthorizationHandler' do
    context 'when a command is sent' do
      context 'when user has opted-out of bot (user.opt_out == true)' do
        it 'does nothing' do
          opted_out_user = create(:user, opt_out: true)
          chat = create(:chat)
          create(:chat_user, chat:, user: opted_out_user)

          known_commands.each do |command|
            expect do
              dispatch_command(
                command.to_sym,
                {
                  date: Time.current.to_i,
                  from: Telegram::Bot::Types::User.new(
                    id: opted_out_user.api_id,
                    is_bot: false,
                    first_name: opted_out_user.first_name,
                    username: opted_out_user.username,
                    language_code: 'en'
                  ),
                  chat: Telegram::Bot::Types::Chat.new(
                    id: chat.api_id,
                    type: 'supergroup',
                    title: chat.title
                  )
                }
              )
            end.to raise_error(FuckyWuckies::AuthorizationError, /opted-out user/)
          end
        end
      end

      context 'when unauthorized' do
        it 'refuses to run commands from other bots' do
          allow_any_instance_of(described_class).to receive(:handle_error).and_raise(
            FuckyWuckies::AuthorizationError
          )

          expect do
            dispatch_command summarize_chat: { from: Telegram::Bot::Types::User.new(
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
            dispatch_command summarize_chat: { chat: Telegram::Bot::Types::Chat.new(
              id: 23456,
              type: 'private',
              title: "Someone's DMs"
            ) }
          end.to raise_error(FuckyWuckies::AuthorizationError)

          expect do
            dispatch_command summarize_chat: { chat: Telegram::Bot::Types::Chat.new(
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
            dispatch_command summarize_chat: { chat: Telegram::Bot::Types::Chat.new(
              id: 23456,
              type: 'group',
              title: 'Some group'
            ) }
          end.to raise_error(FuckyWuckies::AuthorizationError)

          expect do
            dispatch_command summarize_chat: { chat: Telegram::Bot::Types::Chat.new(
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
