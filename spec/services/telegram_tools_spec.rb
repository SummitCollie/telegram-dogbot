# frozen_string_literal: true

require 'rails_helper'
require 'support/telegram_helpers'

RSpec.describe TelegramTools do
  include_context 'with telegram_helpers'

  describe '#serialize_api_message' do
    it 'serializes fields we want from api message' do
      api_message = Telegram::Bot::Types::Message.new(default_message_options.merge(text: 'message text'))

      result = described_class.serialize_api_message(api_message)

      expect(result).to eq({
        message_id: api_message.message_id,
        text: api_message.text,
        date: api_message.date,
        from: {
          first_name: api_message.from.first_name,
          username: api_message.from.username
        }
      }.to_json)
    end

    context 'when api message is a sticker' do
      it 'serializes sticker emoji as message text' do
        api_message = Telegram::Bot::Types::Message.new(default_message_options.merge(sticker_message_options))

        result = JSON.parse(described_class.serialize_api_message(api_message))

        emoji = api_message.sticker.emoji
        expect(result['text']).to eq "#{emoji} (#{Unicode::Name.of(emoji).downcase})"
      end
    end

    context 'when api message contains a media caption' do
      it 'serializes media caption as message text' do
        api_message = Telegram::Bot::Types::Message.new(default_message_options.merge(photo_message_options))

        result = JSON.parse(described_class.serialize_api_message(api_message))

        expect(result['text']).to eq api_message.caption
      end
    end

    context 'when api messge is a reply to another message' do
      it 'serializes api_message.reply_to_message' do
        replied_message = Telegram::Bot::Types::Message.new(
          default_message_options.merge(date: 1.minute.ago.to_i)
        )
        api_message = Telegram::Bot::Types::Message.new({
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
                                                          ),
                                                          reply_to_message: replied_message
                                                        })

        result = JSON.parse(described_class.serialize_api_message(api_message))

        expect(result['reply_to_message']).to eq({
          message_id: replied_message.message_id,
          text: replied_message.text,
          date: replied_message.date,
          from: {
            first_name: replied_message.from.first_name,
            username: replied_message.from.username
          }
        }.deep_stringify_keys)
      end
    end
  end
end
