# frozen_string_literal: true

require 'rails_helper'
require 'telegram/bot/rspec/integration/rails'

RSpec.describe TelegramWebhooksController, telegram_bot: :rails do
  # rubocop:disable RSpec/BeforeAfterAll
  before :all do
    Rails.application.credentials.chat_id_whitelist = [12345]
  end
  # rubocop:enable RSpec/BeforeAfterAll

  def default_message_options
    {
      message_id: rand(1000..9999),
      date: Time.current.to_i,
      from: Telegram::Bot::Types::User.new(
        id: 123456789,
        is_bot: false,
        first_name: 'First Name String',
        username: 'tgUsernameString',
        language_code: 'en'
      ),
      chat: Telegram::Bot::Types::Chat.new(
        id: 12345,
        type: 'group',
        title: 'Chatroom Name String',
        all_members_are_administrators: true
      )
    }
  end

  let(:photo_message_options) {{
    photo: [Telegram::Bot::Types::PhotoSize.new],
    caption: 'Photo message caption text'
  }}

  let(:video_message_options) {{
    video: Telegram::Bot::Types::Video.new,
    caption: 'Video message caption text'
  }}

  describe '#message' do
    context 'when message should be stored' do
      it 'creates User record if missing' do
        expect do
          dispatch_message('text')
        end.to change(User, :count).by(1)

        # Ensure a second message from same user doesn't create additional user record
        expect do
          dispatch_message('text')
        end.not_to change(User, :count)
      end

      it 'creates Chat record if missing' do
        expect do
          dispatch_message('text')
        end.to change(Chat, :count).by(1)

        # Ensure a second message from same chat doesn't create additional chat record
        expect do
          dispatch_message('text')
        end.not_to change(Chat, :count)
      end

      it 'stores messages from whitelisted group chats' do
        dispatch_message('text')

        user = User.find_by(api_id: default_message_options[:from][:id])
        message = user.messages.last

        expect(message.text).to eq 'text'
      end

      it 'stores caption & media type messages with media attached' do
        # Photo message
        dispatch_message(nil, photo_message_options)

        user = User.find_by(api_id: default_message_options[:from][:id])
        message = user.messages.last

        expect(message.text).to eq 'Photo message caption text'
        expect(message.attachment_type).to eq 'photo'

        # Video message
        dispatch_message(nil, video_message_options)

        message = user.messages.last

        expect(message.text).to eq 'Video message caption text'
        expect(message.attachment_type).to eq 'video'
      end
    end

    context 'when a message is edited' do
      describe '#edited_message' do
        it 'updates existing Message record if found' do
          # Original message
          original_options = default_message_options
          dispatch_message('Original text', original_options)

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
      end
    end

    context 'when message should not be stored' do
      it 'does not create User record for unauthorized chats'
      it 'does not create Chat record for unauthorized chats'
      it 'does not store messages from unauthorized group chats'
      it 'does not store messages from non-group chats'
      it 'does not store messages from other bots'
      it 'does not store messages with empty text'
    end
  end

  context 'when a command is sent' do
    context 'when receiving a command' do
      describe '#summarize!'
      describe '#summarize_nicely!'
      describe '#summarize_tinfoil!'
      describe '#vibe_check!'
      describe '#stats!'
    end

    context 'for unsupported commands' do
      subject { -> { dispatch time_travel: {back_to: :the_future} } }
      it 'does nothing' do
        subject.call
        expect(response).to be_ok
      end
    end
  end
end
