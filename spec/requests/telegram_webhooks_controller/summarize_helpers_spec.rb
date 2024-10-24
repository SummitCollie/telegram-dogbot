# frozen_string_literal: true

require 'rails_helper'
require 'telegram/bot/rspec/integration/rails'
require 'support/telegram_helpers'

RSpec.describe TelegramWebhooksController, telegram_bot: :rails do
  include ActiveJob::TestHelper
  include_context 'with telegram_helpers'

  describe 'TelegramWebhooksController::SummarizeHelpers' do
    before do
      Rails.application.credentials.whitelist_enabled = false
    end

    let(:chat) { create(:chat) }
    let(:messages) do
      Array.new(100) do
        create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
      end.sort_by(&:date)
    end

    context 'when no SummarizeChatJob is running for this chat' do
      before do
        ChatSummary.destroy_all
      end

      it 'enqueues a SummarizeChatJob' do
        expect do
          dispatch_command(:summarize_chat, { chat: Telegram::Bot::Types::Chat.new(
            id: chat.api_id,
            type: 'supergroup',
            title: chat.title
          ) })
        end.to have_enqueued_job(LLM::SummarizeChatJob)
      end

      it 'creates a ChatSummary record' do
        expect do
          dispatch_command(:summarize_chat, { chat: Telegram::Bot::Types::Chat.new(
            id: chat.api_id,
            type: 'supergroup',
            title: chat.title
          ) })
        end.to change(ChatSummary, :count).by(1)
      end
    end

    context 'when a SummarizeChatJob has been running for this chat for < 1 min' do
      it 'refuses to enqueue another SummarizeChatJob' do
        create(:chat_summary, chat:, status: :running)

        expect do
          dispatch_command(:summarize_chat, { chat: Telegram::Bot::Types::Chat.new(
            id: chat.api_id,
            type: 'supergroup',
            title: chat.title
          ) })
        end.not_to have_enqueued_job(LLM::SummarizeChatJob)
      end

      it 'does not create a ChatSummary record' do
        create(:chat_summary, chat:, status: :running)

        expect do
          dispatch_command(:summarize_chat, { chat: Telegram::Bot::Types::Chat.new(
            id: chat.api_id,
            type: 'supergroup',
            title: chat.title
          ) })
        end.not_to change(ChatSummary, :count)
      end
    end

    context 'when a SummarizeChatJob has been running for this chat for > 1 min' do
      it 'deletes existing timed-out SummarizeChatJob' do
        old_summary = create(:chat_summary, chat:, status: :running, created_at: 2.minutes.ago)

        dispatch_command(:summarize_chat, { chat: Telegram::Bot::Types::Chat.new(
          id: chat.api_id,
          type: 'supergroup',
          title: chat.title
        ) })

        expect { old_summary.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'enqueues a new SummarizeChatJob' do
        create(:chat_summary, chat:, status: :running, created_at: 2.minutes.ago)

        expect do
          dispatch_command(:summarize_chat, { chat: Telegram::Bot::Types::Chat.new(
            id: chat.api_id,
            type: 'supergroup',
            title: chat.title
          ) })
        end.to have_enqueued_job(LLM::SummarizeChatJob)
      end
    end

    context 'when summarize_chat command is provided with a custom style' do
      it 'sets summary_type to :custom and saves style text to DB'
    end

    context 'when summarize_chat command is NOT provided with a custom style' do
      it 'sets summary_type to :default and leaves DB style text as nil'
    end

    describe '#parse_summarize_url_command' do
      it 'enqueues a SummarizeUrlJob'

      context 'when URL is present in command message' do
        it 'prioritizes command message URL over any URL in the message it was replying to'
      end

      context 'when URL is not present in command message' do
        it 'uses the first URL from the msg which command msg was replying to'
        it 'shows help info when no URL in command or replied message'
      end

      context 'when style text comes before URL' do
        it 'correctly parses URL and style text'
      end

      context 'when style text comes after URL' do
        it 'also correctly parses URL and style text'
      end

      context 'when style text exists before and after URL' do
        it 'correctly parses URL and joins style text with a comma'
      end
    end
  end
end
