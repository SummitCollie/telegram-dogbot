# frozen_string_literal: true

RSpec.shared_context 'with telegram_helpers' do
  let(:known_commands) { %w[summarize summarize_chat vibe_check translate chat_stats].freeze }

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
end
