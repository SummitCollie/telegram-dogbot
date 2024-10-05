# frozen_string_literal: true

require 'rails_helper'
require 'telegram/bot/rspec/integration/rails'
require 'support/telegram_webhooks_controller_helpers'

RSpec.describe TelegramWebhooksController, telegram_bot: :rails do
  include ActiveJob::TestHelper
  include_context 'with telegram_webhooks_controller_helpers'

  describe 'TelegramWebhooksController::ChatStatsHelpers' do
    before do
      Rails.application.credentials.whitelist_enabled = false
    end

    it 'responds with the correct stats' do
      chat = create(:chat)
      user1 = create(:user)
      user2 = create(:user)
      user3 = create(:user)

      Message.transaction do
        # User 1: 5 messages total including dispatch_command in `expect` below
        cu1 = create(:chat_user, chat:, user: user1, num_chatuser_messages: 4)
        4.times do
          create(:message, chat_user: cu1, date: Faker::Time.backward(days: 1))
        end

        # User 2: 2 messages in DB
        cu2 = create(:chat_user, chat:, user: user2, num_chatuser_messages: 2)
        2.times do
          create(:message, chat_user: cu2, date: Faker::Time.backward(days: 1))
        end

        # User 3: no messages in DB, but racked up a message count of 4 earlier
        create(:chat_user, chat:, user: user3, num_chatuser_messages: 4)
      end

      expect do
        dispatch_command(
          :chat_stats,
          {
            chat: Telegram::Bot::Types::Chat.new(id: chat.api_id,
                                                 type: 'supergroup',
                                                 title: chat.title),
            from: Telegram::Bot::Types::User.new(
              id: user1.api_id,
              first_name: user1.first_name,
              username: user1.username
            )
          }
        )
      end.to send_telegram_message(bot, <<~RESULT.strip
        📊 Chat Stats
          • Total Messages: 11
          • Last 2 days: 7 (63.636%)

        🗣 Top Yappers - 2 days
          1. #{user1.first_name} / 5 msgs (71.4%)
          2. #{user2.first_name} / 2 msgs (28.6%)
          3. #{user3.first_name} / 0 msgs (0.0%)

        ⭐️ Top Yappers - all time
          1. #{user1.first_name} / 5 msgs (45.5%)
          2. #{user3.first_name} / 4 msgs (36.4%)
          3. #{user2.first_name} / 2 msgs (18.2%)
      RESULT
      )
    end
  end
end
