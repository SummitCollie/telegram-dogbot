# frozen_string_literal: true

require 'rails_helper'
require 'telegram/bot/rspec/integration/rails'

RSpec.describe TelegramWebhooksController, telegram_bot: :rails do
  include ActiveJob::TestHelper

  let(:known_commands) { %w[summarize summarize_nicely vibe_check translate].freeze }

  let(:photo_message_options) do
    {
      photo: [Telegram::Bot::Types::PhotoSize.new],
      caption: 'Photo message caption text'
    }
  end

  let(:video_message_options) do
    {
      video: Telegram::Bot::Types::Video.new,
      caption: 'Video message caption text'
    }
  end

  let(:sticker_message_options) do
    {
      sticker: {
        file_id: 'sticker_file_id',
        emoji: '🙂'
      }
    }
  end

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

  # rubocop:disable RSpec/BeforeAfterAll
  before :all do
    Rails.application.credentials.whitelist_enabled = true
    Rails.application.credentials.chat_id_whitelist = [12345]
  end
  # rubocop:enable RSpec/BeforeAfterAll

  describe '#message' do
    context 'when message should be stored' do
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

      it 'saves known bot commands' do
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

    context 'when message should not be stored' do
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

      it 'does not store messages from other bots' do
        expect do
          dispatch_message 'text', { from: Telegram::Bot::Types::User.new(
            id: 9999999,
            is_bot: true,
            first_name: 'Botty',
            username: 'tgBotUsername',
            language_code: 'en'
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

  context 'when a command is sent' do
    it 'does not store command message' do
      expect do
        dispatch_command :summarize, { from: Telegram::Bot::Types::User.new(
          id: 9999999,
          is_bot: true,
          first_name: 'Botty',
          username: 'tgBotUsername',
          language_code: 'en'
        ) }
      end.not_to change(Message, :count)
    end

    describe '#summarize!' do
      context 'when no SummarizeChatJob is running for this chat' do
        let(:chat) { create(:chat, api_id: 12345) }
        let(:messages) do
          Array.new(100) do
            create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
          end.sort_by(&:date)
        end

        before do
          ChatSummary.destroy_all
        end

        it 'enqueues a SummarizeChatJob' do
          expect do
            dispatch_command(:summarize, { chat: Telegram::Bot::Types::Chat.new(
              id: chat.api_id,
              type: 'supergroup',
              title: chat.title
            ) })
          end.to have_enqueued_job(LLM::SummarizeChatJob)
        end

        it 'creates a ChatSummary record' do
          expect do
            dispatch_command(:summarize, { chat: Telegram::Bot::Types::Chat.new(
              id: chat.api_id,
              type: 'supergroup',
              title: chat.title
            ) })
          end.to change(ChatSummary, :count).by(1)
        end
      end

      context 'when a SummarizeChatJob is already running for this chat' do
        let(:chat) { create(:chat, api_id: 12345) }
        let(:messages) do
          Array.new(100) do
            create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
          end.sort_by(&:date)
        end

        it 'refuses to enqueue another SummarizeChatJob' do
          create(:chat_summary, chat:, status: :running)

          expect do
            dispatch_command(:summarize, { chat: Telegram::Bot::Types::Chat.new(
              id: chat.api_id,
              type: 'supergroup',
              title: chat.title
            ) })
          end.not_to have_enqueued_job(LLM::SummarizeChatJob)
        end

        it 'does not create a ChatSummary record' do
          create(:chat_summary, chat:, status: :running)

          expect do
            dispatch_command(:summarize, { chat: Telegram::Bot::Types::Chat.new(
              id: chat.api_id,
              type: 'supergroup',
              title: chat.title
            ) })
          end.not_to change(ChatSummary, :count)
        end
      end
    end

    describe '#translate!' do
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

    describe '#stats!' do
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
            :stats,
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
end

# Need to use this lower-level syntax to allow mocks
# https://github.com/telegram-bot-rb/telegram-bot?tab=readme-ov-file#testing
require 'telegram/bot/updates_controller/rspec_helpers'
RSpec.describe TelegramWebhooksController, type: :telegram_bot_controller do
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
