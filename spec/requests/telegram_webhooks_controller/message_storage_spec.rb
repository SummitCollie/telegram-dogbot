# frozen_string_literal: true

require 'rails_helper'
require 'telegram/bot/rspec/integration/rails'
require 'support/telegram_webhooks_controller_helpers'

RSpec.describe TelegramWebhooksController, telegram_bot: :rails do
  include ActiveJob::TestHelper
  include_context 'with telegram_webhooks_controller_helpers'

  describe 'TelegramWebhooksController::MessageStorage' do
    before do
      Rails.application.credentials.whitelist_enabled = true
      Rails.application.credentials.chat_id_whitelist = [12345]
    end

    context 'when message storage is authorized' do
      it 'creates User record if missing' do
        expect do
          dispatch_message 'text'
        end.to change(User, :count).by(1)

        # Ensure a second message from same user doesn't create additional user record
        expect do
          dispatch_message 'text'
        end.not_to change(User, :count)
      end

      it 'creates Chat record if missing' do
        expect do
          dispatch_message 'text'
        end.to change(Chat, :count).by(1)

        # Ensure a second message from same chat doesn't create additional chat record
        expect do
          dispatch_message 'text'
        end.not_to change(Chat, :count)
      end

      it 'stores messages from whitelisted group chats' do
        options = default_message_options
        dispatch_message 'text', options

        user = User.find_by(api_id: options[:from][:id])
        message = user.messages.last

        expect(message.text).to eq 'text'
        expect(message.date.to_i).to eq options[:date]
        expect(message.attachment_type).to be_nil
      end

      it 'stores caption & media type messages with media attached' do
        # Photo message
        dispatch_message nil, photo_message_options

        user = User.find_by(api_id: default_message_options[:from][:id])
        message = user.messages.last

        expect(message.text).to eq 'Photo message caption text'
        expect(message.attachment_type).to eq 'photo'

        # Video message
        dispatch_message nil, video_message_options

        message = user.messages.last

        expect(message.text).to eq 'Video message caption text'
        expect(message.attachment_type).to eq 'video'
      end

      it 'tracks message replies' do
        options = default_message_options
        dispatch_message 'Original message', options

        user = User.find_by(api_id: options[:from].id)
        message1 = user.messages.last

        dispatch_message 'Reply message', {
          reply_to_message: Telegram::Bot::Types::Message.new(
            message_id: message1.api_id
          )
        }
        message2 = user.messages.last

        expect(message1.reload.replies).to include(message2)
        expect(message2.reply_to_message).to eq message1
      end

      it 'saves related emoji from sticker messages as message text' do
        options = default_message_options.merge(sticker_message_options)
        dispatch_message nil, options

        user = User.find_by(api_id: options[:from].id)
        message1 = user.messages.last

        expect(message1.reload.text).to eq(options[:sticker][:emoji])
      end

      it 'saves messages from other bots' do
        expect do
          dispatch_message 'text', { from: Telegram::Bot::Types::User.new(
            id: 9999999,
            is_bot: true,
            first_name: 'Botty',
            username: 'tgBotUsername',
            language_code: 'en'
          ) }
        end.to change(Message, :count)
           .and change(User, :count)
           .and change(Chat, :count)
      end

      it 'saves commands for this bot' do
        chat = create(:chat, api_id: 12345)

        known_commands.each do |command|
          dispatch_command(command.to_sym, {
                             date: Time.current.to_i,
                             from: Telegram::Bot::Types::User.new(
                               id: 123456789,
                               is_bot: false,
                               first_name: 'First Name String',
                               username: 'tgUsernameString',
                               language_code: 'en'
                             ),
                             chat: Telegram::Bot::Types::Chat.new(
                               id: chat.api_id,
                               type: 'supergroup',
                               title: chat.title
                             )
                           })

          new_message = chat.messages.order(:date).reload.last

          expect(new_message.text).to match %r{^/#{command}?+}
        end
      end

      it 'saves unknown bot commands' do
        chat = create(:chat, api_id: 12345)

        dispatch_command(:some_unsupported_command, {
                           date: Time.current.to_i,
                           from: Telegram::Bot::Types::User.new(
                             id: 123456789,
                             is_bot: false,
                             first_name: 'First Name String',
                             username: 'tgUsernameString',
                             language_code: 'en'
                           ),
                           chat: Telegram::Bot::Types::Chat.new(
                             id: chat.api_id,
                             type: 'supergroup',
                             title: chat.title
                           )
                         })

        new_message = chat.messages.order(:date).reload.last

        expect(new_message.text).to eq '/some_unsupported_command'
      end
    end

    context 'when a message is edited' do
      describe '#edited_message' do
        it 'updates existing Message record if found' do
          # Original message
          original_options = default_message_options
          dispatch_message 'Original text', original_options

          user = User.find_by(api_id: original_options[:from][:id])
          message = user.messages.last

          expect(message.text).to eq 'Original text'

          # Dispatch edit
          dispatch edited_message: original_options.merge(
            edit_date: Time.current.to_i,
            text: 'Edited text'
          )

          message.reload
          expect(message.text).to eq 'Edited text'
        end

        it 'ignores the edit if original message not stored' do
          expect do
            dispatch edited_message: default_message_options.merge(
              edit_date: Time.current.to_i,
              text: 'Edited text'
            )
          end.not_to change(Message, :count)
        end

        it 'does not change the datetime of the original message' do
          # Original message
          original_options = default_message_options
          dispatch_message 'Original text', original_options

          user = User.find_by(api_id: original_options[:from][:id])
          message = user.messages.last

          expect(message.text).to eq 'Original text'

          # Dispatch edit
          dispatch edited_message: original_options.merge(
            edit_date: 1.minute.from_now.to_i,
            text: 'Edited text'
          )

          message.reload
          expect(message.date.to_i).to eq original_options[:date]
        end
      end
    end

    context 'when message storage is NOT authorized' do
      it 'does not create User record for non-whitelisted chats' do
        expect do
          dispatch_message 'text', { chat: { id: 0o0000 } }
        end.not_to change(User, :count)
      end

      it 'does not create Chat record for non-whitelisted chats' do
        expect do
          dispatch_message 'text', { chat: { id: 0o0000 } }
        end.not_to change(Chat, :count)
      end

      it 'does not store messages from non-whitelisted group chats' do
        expect do
          dispatch_message 'text', { chat: { id: 0o0000 } }
        end.not_to change(Message, :count)
      end

      it 'does not store messages from non-group chats' do
        expect do
          dispatch_message 'text', { chat: Telegram::Bot::Types::Chat.new(
            id: 23456,
            type: 'private',
            title: "Someone's DMs"
          ) }
          dispatch_message 'text', { chat: Telegram::Bot::Types::Chat.new(
            id: 34567,
            type: 'channel',
            title: 'Some channel'
          ) }
        end.to not_change(Message, :count)
           .and not_change(User, :count)
           .and not_change(Chat, :count)
      end

      it 'does not store messages with empty text' do
        expect do
          # Empty plain text message
          dispatch message: default_message_options.merge(text: nil)

          # Media message with no caption
          dispatch_message nil, { photo: [Telegram::Bot::Types::PhotoSize.new],
                                  caption: nil }
        end.not_to change(Message, :count)
      end
    end

    context 'when whitelist is disabled' do
      before do
        Rails.application.credentials.whitelist_enabled = false
      end

      it 'stores messages from chats not present in whitelist' do
        options = default_message_options
        options[:chat] = Telegram::Bot::Types::Chat.new(
          id: 12345678,
          type: 'group',
          title: 'Non-whitelisted Chat',
          all_members_are_administrators: true
        )

        dispatch_message 'text', options

        user = User.find_by(api_id: options[:from][:id])
        message = user.messages.last

        expect(message.text).to eq 'text'
        expect(message.date.to_i).to eq options[:date]
        expect(message.attachment_type).to be_nil
      end
    end
  end
end
