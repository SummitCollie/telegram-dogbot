# frozen_string_literal: true

require 'rails_helper'
require 'telegram/bot/rspec/integration/rails'
require 'support/telegram_helpers'

RSpec.describe TelegramWebhooksController, telegram_bot: :rails do
  include ActiveJob::TestHelper

  include_context 'with telegram_helpers'

  describe 'TelegramWebhooksController::DescribeHelpers' do
    let(:chat) { create(:chat, api_id: 12345) }
    let(:vision_chats) { [chat.api_id] }
    let(:vision_model_up) { true }
    let(:photo) do
      create(:message, chat:, attachment_type: :photo, image_status: :described,
                       image_description: 'a shiba inu in sunglasses')
    end

    def describe_command(reply_to: photo)
      target = reply_to && Telegram::Bot::Types::Message.new(
        default_message_options.merge(message_id: reply_to.api_id, text: reply_to.text)
      )
      dispatch_command(:describe, default_message_options.merge(reply_to_message: target).compact)
    end

    before do
      Rails.application.credentials.whitelist_enabled = false
      allow(Rails.application.credentials).to receive(:vision_chat_id_whitelist).and_return vision_chats
      allow(LocalInferenceApi).to receive_messages(available_model: ('local-model' if vision_model_up),
                                                   vision?: vision_model_up)
    end

    it 'replies with the description of the image in the replied-to message' do
      expect { describe_command }.to send_telegram_message(bot, '[photo: a shiba inu in sunglasses]')
    end

    it 'does not store the command or its reply' do
      photo

      expect { describe_command }.not_to change(Message, :count)
    end

    it 'explains itself without a replied-to message' do
      chat
      expect { describe_command(reply_to: nil) }.to send_telegram_message(bot, /Reply to a photo/)
    end

    it 'says when there is nothing to describe' do
      expect { describe_command(reply_to: create(:message, chat:)) }
        .to send_telegram_message(bot, 'Nothing to describe in that message')
    end

    %w[pending failed].each do |status|
      context "when the image is #{status}" do
        before { photo.update!(image_status: status, image_description: nil) }

        it 'queues describing it (again)' do
          expect { describe_command }.to send_telegram_message(bot, /looking at it now/)

          expect(photo.reload.image_status).to eq 'pending'
          expect(LLM::DescribeImageJob).to have_been_enqueued.with(photo.id)
        end

        context 'when the model that can see images is unavailable' do
          let(:vision_model_up) { false }

          it 'says so' do
            expect { describe_command }.to send_telegram_message(bot, /isn't available right now/)

            expect(LLM::DescribeImageJob).not_to have_been_enqueued
          end
        end
      end
    end

    context 'when chat does not have vision enabled' do
      let(:vision_chats) { [] }

      it 'says so' do
        expect { describe_command }.to send_telegram_message(bot, "Images aren't described in this chat")
      end
    end
  end
end
