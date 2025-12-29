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
      it 'sets summary_type to :custom and saves style text to DB' do
        style = 'as if you were falling asleep while writing'

        dispatch_command(:summarize_chat, style, {
                           chat: Telegram::Bot::Types::Chat.new(
                             id: chat.api_id,
                             type: 'supergroup',
                             title: chat.title
                           )
                         })

        summary = chat.chat_summaries.order(:created_at).last
        expect(summary).to have_attributes(
          chat_id: chat.id,
          summary_type: 'custom',
          style:
        )
      end
    end

    context 'when summarize_chat command is NOT provided with a custom style' do
      it 'sets summary_type to :default and leaves DB style text as nil' do
        dispatch_command(:summarize_chat, {
                           chat: Telegram::Bot::Types::Chat.new(
                             id: chat.api_id,
                             type: 'supergroup',
                             title: chat.title
                           )
                         })

        summary = chat.chat_summaries.order(:created_at).last
        expect(summary).to have_attributes(
          chat_id: chat.id,
          summary_type: 'default',
          style: nil
        )
      end

      it 'enqueues a SummarizeChatJob' do
        expect do
          dispatch_command(:summarize_chat, {
                             chat: Telegram::Bot::Types::Chat.new(
                               id: chat.api_id,
                               type: 'supergroup',
                               title: chat.title
                             )
                           })
        end.to have_enqueued_job(LLM::SummarizeChatJob)
      end
    end

    describe '#parse_summarize_url_command' do
      let(:command_url) { 'https://command.com/article' }
      let(:replied_url) { 'https://replied.com/article' }

      let(:other_user) { create(:user) }
      let(:other_user_cu) { create(:chat_user, chat:, user: other_user) }

      let(:replied_message) do
        create(:message, text: "#{replied_url} command was a reply to this msg",
                         created_at: 1.minute.ago,
                         chat_user: other_user_cu)
      end
      let(:api_replied_message) do
        Telegram::Bot::Types::Message.new(
          message_id: replied_message.api_id,
          text: replied_message.text,
          date: replied_message.date,
          from: Telegram::Bot::Types::User.new(
            id: other_user.api_id,
            is_bot: false,
            first_name: other_user.first_name,
            username: other_user.username
          ),
          chat: Telegram::Bot::Types::Chat.new(
            id: chat.api_id,
            title: chat.title
          ),
          entities: [
            Telegram::Bot::Types::MessageEntity.new(
              type: 'url', offset: 0, length: replied_url.length
            )
          ]
        )
      end

      context 'when URL is present in command message' do
        it 'prioritizes command message URL over any URL in the message it was replying to' do
          expect do
            dispatch_command(
              :summarize_url,
              command_url,
              {
                chat: Telegram::Bot::Types::Chat.new(
                  id: chat.api_id,
                  type: 'supergroup',
                  title: chat.title
                ),
                entities: [
                  Telegram::Bot::Types::MessageEntity.new(
                    type: 'url',
                    offset: '/summarize_url '.length,
                    length: command_url.length
                  )
                ],
                reply_to_message: api_replied_message
              }
            )
          end.to have_enqueued_job(LLM::SummarizeUrlJob).with(chat, command_url, '')
        end
      end

      context 'when URL is not present in command message' do
        context 'when URL is present in replied message' do
          it 'uses the first URL from the msg which command msg was replying to' do
            expect do
              dispatch_command(
                :summarize_url,
                {
                  reply_to_message: api_replied_message,
                  chat: Telegram::Bot::Types::Chat.new(
                    id: chat.api_id,
                    type: 'supergroup',
                    title: chat.title
                  )
                }
              )
            end.to have_enqueued_job(LLM::SummarizeUrlJob).with(chat, replied_url, '')
          end

          it 'uses style text from the command message' do
            expect do
              dispatch_command(
                :summarize_url,
                'as a note hastily scribbled on a napkin',
                {
                  reply_to_message: api_replied_message,
                  chat: Telegram::Bot::Types::Chat.new(
                    id: chat.api_id,
                    type: 'supergroup',
                    title: chat.title
                  )
                }
              )
            end.to have_enqueued_job(LLM::SummarizeUrlJob).with(chat, replied_url,
                                                                'as a note hastily scribbled on a napkin')
          end
        end

        # rubocop:disable Style/PercentLiteralDelimiters
        it 'shows help info when no URL in command or replied message' do
          replied_message_without_url = api_replied_message.clone
          replied_message_without_url.attributes.merge!(
            entities: [],
            text: 'no url here'
          )

          expect do
            dispatch_command(
              :summarize_url,
              {
                reply_to_message: replied_message_without_url,
                chat: Telegram::Bot::Types::Chat.new(
                  id: chat.api_id,
                  type: 'supergroup',
                  title: chat.title
                )
              }
            )
          end.to send_telegram_message(bot, %r:📝 <b><u>Summarize URL</u></b>:)
        end
        # rubocop:enable Style/PercentLiteralDelimiters
      end

      context 'when style text comes before URL' do
        it 'correctly parses URL and style text' do
          url = 'https://whatever.net'
          style_text = 'as a letter from my landlord'

          expect do
            dispatch_command(
              :summarize_url,
              "#{style_text} #{url}",
              {
                chat: Telegram::Bot::Types::Chat.new(
                  id: chat.api_id,
                  type: 'supergroup',
                  title: chat.title
                ),
                entities: [
                  Telegram::Bot::Types::MessageEntity.new(
                    type: 'url',
                    offset: "/summarize_url #{style_text} ".length,
                    length: url.length
                  )
                ]
              }
            )
          end.to have_enqueued_job(LLM::SummarizeUrlJob).with(chat, url, style_text)
        end
      end

      context 'when style text comes after URL' do
        it 'also correctly parses URL and style text' do
          url = 'https://whatever.net'
          style_text = 'as a letter from my landlord'

          expect do
            dispatch_command(
              :summarize_url,
              "#{url} #{style_text}",
              {
                chat: Telegram::Bot::Types::Chat.new(
                  id: chat.api_id,
                  type: 'supergroup',
                  title: chat.title
                ),
                entities: [
                  Telegram::Bot::Types::MessageEntity.new(
                    type: 'url',
                    offset: '/summarize_url '.length,
                    length: url.length
                  )
                ]
              }
            )
          end.to have_enqueued_job(LLM::SummarizeUrlJob).with(chat, url, style_text)
        end
      end

      context 'when style text exists before and after URL' do
        it 'correctly parses URL and joins style text with a comma' do
          url = 'https://whatever.net'
          style_text_pre = 'with a high level of contempt'
          style_text_post = 'as a letter from my landlord'

          expect do
            dispatch_command(
              :summarize_url,
              "#{style_text_pre} #{url} #{style_text_post}",
              {
                chat: Telegram::Bot::Types::Chat.new(
                  id: chat.api_id,
                  type: 'supergroup',
                  title: chat.title
                ),
                entities: [
                  Telegram::Bot::Types::MessageEntity.new(
                    type: 'url',
                    offset: "/summarize_url #{style_text_pre} ".length,
                    length: url.length
                  )
                ]
              }
            )
          end.to have_enqueued_job(LLM::SummarizeUrlJob).with(chat, url, "#{style_text_pre}, #{style_text_post}")
        end
      end
    end
  end
end
