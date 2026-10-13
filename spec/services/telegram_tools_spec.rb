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
        },
        image_file_id: nil
      }.to_json)
    end

    it "serializes file_id of the message's image, and of the one it replies to" do
      replied_message = Telegram::Bot::Types::Message.new(default_message_options.merge(sticker_message_options))
      api_message = Telegram::Bot::Types::Message.new(
        default_message_options.merge(photo: [{ file_id: 'photo_file_id', width: 800, height: 600 }],
                                      reply_to_message: replied_message)
      )

      result = JSON.parse(described_class.serialize_api_message(api_message))

      expect(result['image_file_id']).to eq 'photo_file_id'
      expect(result.dig('reply_to_message', 'image_file_id')).to eq 'sticker_file_id'
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
          },
          attachment_type: nil,
          image_file_id: nil
        }.deep_stringify_keys)
      end

      it "serializes reply_to_message's caption as its text" do
        replied_message = Telegram::Bot::Types::Message.new(default_message_options.merge(photo_message_options))
        api_message = Telegram::Bot::Types::Message.new(
          default_message_options.merge(reply_to_message: replied_message)
        )

        result = JSON.parse(described_class.serialize_api_message(api_message))

        expect(result.dig('reply_to_message', 'text')).to eq photo_message_options[:caption]
      end
    end
  end

  describe '#image_file_id' do
    def message_with(**options)
      Telegram::Bot::Types::Message.new(default_message_options.merge(options))
    end

    it 'picks the largest photo size within MAX_IMAGE_SIZE' do
      photo = [
        { file_id: 'small', width: 90, height: 67 },
        { file_id: 'large', width: 1280, height: 960 },
        { file_id: 'huge', width: 2560, height: 1920 },
        { file_id: 'medium', width: 800, height: 600 }
      ]

      expect(described_class.image_file_id(message_with(photo:))).to eq 'medium'
    end

    it 'picks the smallest photo size when none fit within MAX_IMAGE_SIZE' do
      photo = [{ file_id: 'huge', width: 2560, height: 1920 }, { file_id: 'tall', width: 1000, height: 1500 }]

      expect(described_class.image_file_id(message_with(photo:))).to eq 'tall'
    end

    it "uses static stickers' own file" do
      sticker = { file_id: 'webp', file_unique_id: 'u', is_animated: false, is_video: false }

      expect(described_class.image_file_id(message_with(sticker:))).to eq 'webp'
    end

    [{ is_animated: true }, { is_video: true }].each do |kind|
      it "uses the thumbnail of #{kind.keys.first.to_s.delete_prefix('is_')} stickers" do
        sticker = { file_id: 'not_an_image', file_unique_id: 'u', thumbnail: { file_id: 'thumb' }, **kind }

        expect(described_class.image_file_id(message_with(sticker:))).to eq 'thumb'
      end
    end

    it 'is nil for animated stickers without a thumbnail' do
      sticker = { file_id: 'tgs', file_unique_id: 'u', is_animated: true }

      expect(described_class.image_file_id(message_with(sticker:))).to be_nil
    end

    %i[animation video].each do |type|
      it "uses the thumbnail of #{type} messages" do
        media = { file_id: 'not_an_image', file_unique_id: 'u', width: 1, height: 1, duration: 1,
                  thumbnail: { file_id: 'thumb', file_unique_id: 't', width: 320, height: 240 } }

        expect(described_class.image_file_id(message_with(type => media))).to eq 'thumb'
      end
    end

    it 'is nil without anything to show' do
      expect(described_class.image_file_id(message_with(text: 'hi', **video_message_options))).to be_nil
      expect(described_class.image_file_id(message_with(text: 'hi'))).to be_nil
    end
  end

  describe '#download_file' do
    let(:conn) { instance_double(Faraday::Connection) }
    let(:get_file_response) { { 'ok' => true, 'result' => { 'file_path' => 'photos/file_1.jpg' } } }
    let!(:bot) { stub_telegram_bot(token: 'BOT_TOKEN', get_file: get_file_response) }

    before do
      allow(Faraday).to receive(:new).and_return conn
      allow(conn).to receive(:get).with('photos/file_1.jpg')
                                  .and_return instance_double(Faraday::Response, body: 'jpeg bytes')
    end

    it "downloads the file from Telegram's file server, looking up its path synchronously" do
      expect(described_class.download_file('file_id')).to eq 'jpeg bytes'
      expect(bot).to have_received(:async).with(false)
      expect(bot).to have_received(:get_file).with(file_id: 'file_id')
      expect(Faraday).to have_received(:new).with(hash_including(url: 'https://api.telegram.org/file/botBOT_TOKEN/'))
    end

    it 'raises Telegram::Bot::Error without the bot token when the download fails' do
      allow(conn).to receive(:get).and_raise Faraday::ResourceNotFound.new('not found', { status: 404 })

      expect { described_class.download_file('file_id') }.to raise_error(Telegram::Bot::Error) { |e|
        expect(e.message).to include('file_id=file_id', '404')
        expect(e.message).not_to include 'BOT_TOKEN'
        expect(e.cause).to be_nil
      }
    end

    it 'raises Telegram::Bot::Error when Telegram returns no file path' do
      allow(bot).to receive(:get_file).and_return({ 'ok' => true, 'result' => {} })

      expect { described_class.download_file('file_id') }.to raise_error Telegram::Bot::Error, /No file_path/
    end
  end

  describe '#send_bot_message' do
    let(:chat) { create(:chat) }
    let(:reply_to) { create(:message, chat:) }

    context 'when Telegram returns the sent message' do
      let!(:bot) { stub_telegram_bot }
      let(:sent_at) { 1.minute.ago.change(usec: 0) }

      before do
        allow(bot).to receive(:send_message)
          .and_return({ 'ok' => true, 'result' => { 'message_id' => 777, 'date' => sent_at.to_i } })
      end

      it 'sends message synchronously, even when bot client is in async mode' do
        described_class.send_bot_message(chat, 'hi', reply_to:, protect_content: true)

        expect(bot).to have_received(:async).with(false)
        expect(bot).to have_received(:send_message).with(chat_id: chat.api_id, text: 'hi', protect_content: true)
      end

      it 'stores message with its api_id and date from Telegram' do
        message = described_class.send_bot_message(chat, 'hi', reply_to:)

        expect(message.reload).to have_attributes(
          api_id: 777, date: sent_at, text: 'hi', reply_to_message: reply_to, chat:
        )
        expect(message).to be_from_this_bot
      end
    end

    describe 'collapsing long messages' do
      before { stub_telegram_bot }

      def send_and_get_params(text, **send_params)
        described_class.send_bot_message(chat, text, **send_params)
        telegram_sent_messages.last
      end

      {
        'more than COLLAPSE_MAX_LINES lines' => (1..(TelegramTools::COLLAPSE_MAX_LINES + 1)).map { |i| "line #{i}" }.join("\n"),
        'more than COLLAPSE_MAX_CHARS chars' => 'a' * (TelegramTools::COLLAPSE_MAX_CHARS + 1)
      }.each do |description, text|
        it "sends text with #{description} in an expandable blockquote, storing plain text" do
          message = described_class.send_bot_message(chat, text)

          expect(telegram_sent_messages.last).to include(
            text: "<blockquote expandable>#{text}</blockquote>", parse_mode: 'HTML'
          )
          expect(message.reload.text).to eq text
        end
      end

      {
        'exactly COLLAPSE_MAX_LINES lines' => (1..TelegramTools::COLLAPSE_MAX_LINES).map { |i| "line #{i}" }.join("\n"),
        'exactly COLLAPSE_MAX_CHARS chars' => 'a' * TelegramTools::COLLAPSE_MAX_CHARS
      }.each do |description, text|
        it "sends text with #{description} as-is" do
          expect(send_and_get_params(text)).to eq(chat_id: chat.api_id, text:)
        end
      end

      it 'escapes HTML in collapsed text' do
        text = "<b>not bold</b> & stuff\n" * 6

        expect(send_and_get_params(text)[:text])
          .to eq "<blockquote expandable>#{"&lt;b&gt;not bold&lt;/b&gt; &amp; stuff\n" * 6}</blockquote>"
      end

      it 'does not touch text when caller sets its own parse_mode' do
        text = "<b>line</b>\n" * 6

        expect(send_and_get_params(text, parse_mode: 'HTML')).to eq(chat_id: chat.api_id, text:, parse_mode: 'HTML')
      end
    end

    context 'with replace_message_id' do
      let!(:bot) { stub_telegram_bot(edit_message_text: true, delete_message: true) }

      before do
        allow(bot).to receive(:edit_message_text)
          .and_return({ 'ok' => true, 'result' => { 'message_id' => 555, 'date' => 1.minute.ago.to_i } })
      end

      it 'edits that message into this one, removing its buttons, and stores it' do
        message = described_class.send_bot_message(chat, 'hi', replace_message_id: 555, reply_to:,
                                                               protect_content: false, disable_notification: true)

        expect(bot).to have_received(:edit_message_text)
          .with(chat_id: chat.api_id, message_id: 555, text: 'hi', reply_markup: { inline_keyboard: [] })
        expect(bot).not_to have_received(:send_message)
        expect(message.reload).to have_attributes(api_id: 555, text: 'hi', reply_to_message: reply_to)
      end

      it 'collapses long text in the edit too' do
        text = "line\n" * 6

        described_class.send_bot_message(chat, text, replace_message_id: 555)

        expect(bot).to have_received(:edit_message_text).with(
          hash_including(text: "<blockquote expandable>#{text}</blockquote>", parse_mode: 'HTML')
        )
      end

      it 'deletes that message and sends a new one when editing fails' do
        allow(bot).to receive(:edit_message_text).and_raise Telegram::Bot::Error

        message = described_class.send_bot_message(chat, 'hi', replace_message_id: 555, disable_notification: true)

        expect(bot).to have_received(:delete_message).with(chat_id: chat.api_id, message_id: 555)
        expect(telegram_sent_messages.last).to eq(chat_id: chat.api_id, text: 'hi', disable_notification: true)
        expect(message.reload.api_id).to eq 1_000_001
      end
    end

    context 'when response has no sent message (e.g. stubbed client)' do
      it 'stores message with stub api_id and current date' do
        message = described_class.send_bot_message(chat, 'hi')

        expect(message.reload).to have_attributes(api_id: -1, text: 'hi', date: be_within(5.seconds).of(Time.current))
      end
    end
  end
end
