# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::ReplyJob do
  let(:chat) { create(:chat) }
  let(:human) { create(:user) }
  let(:human_cu) { create(:chat_user, chat:, user: human) }
  let(:bot) { create(:user, is_this_bot: true) }
  let(:bot_cu) { create(:chat_user, chat:, user: bot) }

  let(:bot_message) { create(:message, chat_user: bot_cu, text: 'bot msg text', date: 1.minute.ago) }
  let(:api_bot_msg) do
    Telegram::Bot::Types::Message.new(
      message_id: bot_message.api_id,
      text: bot_message.text,
      date: bot_message.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: bot.api_id,
        is_bot: true,
        first_name: bot.first_name,
        username: bot.username
      )
    )
  end

  let(:human_message) { create(:message, chat_user: human_cu, text: 'reply to bot text', date: Time.current) }
  let(:api_human_msg) do
    Telegram::Bot::Types::Message.new(
      message_id: human_message.api_id,
      text: human_message.text,
      date: human_message.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: human.api_id,
        is_bot: false,
        first_name: human.first_name,
        username: human.username
      )
    )
  end

  let(:other_human_message) { create(:message, chat:, text: 'text from random user', date: 1.minute.ago) }

  let(:api_other_human_msg) do
    Telegram::Bot::Types::Message.new(
      message_id: other_human_message.api_id,
      text: other_human_message.text,
      date: other_human_message.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: other_human_message.user.api_id,
        is_bot: false,
        first_name: other_human_message.user.first_name,
        username: other_human_message.user.username
      )
    )
  end

  let(:old_human_message) { create(:message, chat:, text: 'old message text', date: 3.days.ago) }

  let(:api_old_human_message) do
    Telegram::Bot::Types::Message.new(
      message_id: old_human_message.api_id,
      text: old_human_message.text,
      date: old_human_message.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: old_human_message.user.api_id,
        is_bot: false,
        first_name: old_human_message.user.first_name,
        username: old_human_message.user.username
      )
    )
  end

  let(:bot_mention) do
    create(
      :message,
      chat_user: human_cu,
      text: "hi @#{Rails.application.credentials.telegram.bot.username}",
      date: Time.current
    )
  end

  let(:api_bot_mention) do
    Telegram::Bot::Types::Message.new(
      message_id: bot_mention.api_id,
      text: bot_mention.text,
      date: bot_mention.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: human.api_id,
        is_bot: false,
        first_name: human.first_name,
        username: human.username
      )
    )
  end

  let(:reply_to_bot) do
    create(:message, chat_user: human_cu,
                     text: 'text in msg replying to a bot msg',
                     date: Time.current,
                     reply_to_message: bot_message)
  end

  let(:api_reply_to_bot) do
    Telegram::Bot::Types::Message.new(
      message_id: reply_to_bot.api_id,
      text: reply_to_bot.text,
      date: reply_to_bot.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: human.api_id,
        is_bot: false,
        first_name: human.first_name,
        username: human.username
      ),
      reply_to_message: api_bot_msg
    )
  end

  let(:reply_to_human) do
    create(:message, chat_user: human_cu,
                     text: 'text in msg replying to a random user msg',
                     date: Time.current,
                     reply_to_message: other_human_message)
  end

  let(:api_reply_to_human) do
    Telegram::Bot::Types::Message.new(
      message_id: reply_to_human.api_id,
      text: reply_to_human.text,
      date: reply_to_human.date,
      chat: Telegram::Bot::Types::Chat.new(
        id: chat.api_id,
        title: chat.title
      ),
      from: Telegram::Bot::Types::User.new(
        id: human.api_id,
        is_bot: false,
        first_name: human.first_name,
        username: human.username
      ),
      reply_to_message: api_other_human_msg
    )
  end

  before do
    allow(LLMTools).to receive(:chat_completion)
      .and_return LLMTools::Completion.new(text: 'LLM generated reply text', split_replies: false)

    stub_telegram_bot(send_chat_action: true)
  end

  describe '#perform' do
    it 'does not include messages from other chats in prompt' do
      create_list(:message, 3, chat:)
      c1_messages = chat.messages.order(:date)

      chat2 = create(:chat)
      create_list(:message, 3, chat: chat2)

      expected_prompt = <<~PROMPT.strip
        ---
        - id: #{c1_messages[0].api_id}
          user: #{c1_messages[0].user.first_name} (@#{c1_messages[0].user.username})
          text: #{c1_messages[0].text}
        - id: #{c1_messages[1].api_id}
          user: #{c1_messages[1].user.first_name} (@#{c1_messages[1].user.username})
          text: #{c1_messages[1].text}
        - id: #{c1_messages[2].api_id}
          user: #{c1_messages[2].user.first_name} (@#{c1_messages[2].user.username})
          text: #{c1_messages[2].text}
        - id: #{bot_mention.api_id}
          user: #{human.first_name} (@#{human.username})
          text: hi @#{bot.username}
      PROMPT

      described_class.perform_now(chat, TelegramTools.serialize_api_message(api_bot_mention))

      expect(LLMTools).to have_received(:chat_completion).with(
        system_prompt: anything,
        progress: an_instance_of(LLMProgress),
        messages: [{ role: 'user', content: expected_prompt }]
      )
    end

    context 'when LLM API request fails (all providers)' do
      before { allow(LLMTools).to receive(:chat_completion).and_raise Faraday::ConnectionFailed }

      it 'raises ReplyJobFailure caused by the API error, without sending anything' do
        expect do
          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_bot_mention))
        end.to raise_error(FuckyWuckies::ReplyJobFailure, /Error generating reply/) { |e|
          expect(e.cause).to be_a Faraday::ConnectionFailed
        }

        expect(Telegram.bot).not_to have_received(:send_message)
      end
    end
  end

  describe 'prompt contents' do
    context 'when message mentioning bot is a reply to another message' do
      context 'when message being replied to is within context' do
        it 'does not copy reply_to_message into context' do
          intermediate_msg = create(
            :message,
            chat_user: human_cu,
            text: 'intermediate msg text',
            date: other_human_message.date + 1.second
          )

          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

          expected_prompt = <<~PROMPT.strip
            ---
            - id: #{other_human_message.api_id}
              user: #{other_human_message.user.first_name} (@#{other_human_message.user.username})
              text: #{other_human_message.text}
            - id: #{intermediate_msg.api_id}
              user: #{intermediate_msg.user.first_name} (@#{intermediate_msg.user.username})
              text: #{intermediate_msg.text}
            - id: #{reply_to_human.api_id}
              user: #{human.first_name} (@#{human.username})
              text: #{reply_to_human.text}
              reply_to: #{other_human_message.api_id}
          PROMPT

          expect(LLMTools).to have_received(:chat_completion).with(
            system_prompt: anything,
            progress: an_instance_of(LLMProgress),
            messages: [{ role: 'user', content: expected_prompt }]
          )
        end
      end

      context 'when message being replied to is NOT within context' do
        it 'copies reply_to_message into context above last message' do
          reply_to_human.update!(reply_to_message: old_human_message)
          api_reply_to_human = Telegram::Bot::Types::Message.new(
            message_id: reply_to_human.api_id,
            text: reply_to_human.text,
            date: reply_to_human.date,
            chat: Telegram::Bot::Types::Chat.new(
              id: chat.api_id,
              title: chat.title
            ),
            from: Telegram::Bot::Types::User.new(
              id: human.api_id,
              is_bot: false,
              first_name: human.first_name,
              username: human.username
            ),
            reply_to_message: api_old_human_message
          )

          # Enough messages that the window start moves past old_human_message
          create_list(:message, described_class::CONTEXT_MIN_MESSAGES + described_class::CONTEXT_STEP,
                      chat_user: human_cu,
                      text: 'intermediate msg text',
                      date: other_human_message.date + 1.second)

          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

          expect(LLMTools).to have_received(:chat_completion) do |args|
            results = YAML.parse(args[:messages].last[:content]).children[0].to_ruby

            expect(results.count do |r|
              r['id'] == old_human_message.api_id
            end).to eq 1

            expect(results[-2]).to include(
              'id' => old_human_message.api_id,
              'user' => "#{old_human_message.user.first_name} (@#{old_human_message.user.username})",
              'text' => old_human_message.text
            )
            expect(results[-1]).to include('id' => reply_to_human.api_id, 'reply_to' => old_human_message.api_id)
          end
        end
      end

      context 'when message being replied to is from this bot' do
        it 'puts bot message in an assistant turn, quotes it in `reply_to`' do
          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_bot))

          expected_prompt = <<~PROMPT.strip
            ---
            - id: #{reply_to_bot.api_id}
              user: #{human.first_name} (@#{human.username})
              text: #{reply_to_bot.text}
              reply_to: you ("bot msg text")
          PROMPT

          expect(LLMTools).to have_received(:chat_completion).with(
            system_prompt: anything,
            progress: an_instance_of(LLMProgress),
            messages: [
              { role: 'assistant', content: bot_message.text },
              { role: 'user', content: expected_prompt }
            ]
          )
        end

        it 'truncates long quotes at a word boundary, on one line' do
          bot_message.update!(text: "#{'word ' * 8}\nand then a whole lot more text after that")

          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_bot))

          expect(LLMTools).to have_received(:chat_completion) do |messages:, **|
            reply_to = YAML.safe_load(messages.last[:content]).last['reply_to']
            expect(reply_to).to eq 'you ("word word word word word word word word and...")'
          end
        end

        it 'does not copy bot message into context when outside the window (quote is enough)' do
          bot_message.update!(date: 3.days.ago)
          create_list(:message, described_class::CONTEXT_MIN_MESSAGES + described_class::CONTEXT_STEP,
                      chat_user: human_cu, date: 1.day.ago)

          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_bot))

          expect(LLMTools).to have_received(:chat_completion) do |messages:, **|
            entries = YAML.safe_load(messages.last[:content])
            expect(messages.pluck(:role)).to eq %w[user]
            expect(entries.pluck('text')).not_to include bot_message.text
            expect(entries.last['reply_to']).to eq 'you ("bot msg text")'
          end
        end
      end

      context 'when message being replied to is NOT from this bot' do
        it 'puts actual `api_id` value into YAML `id` & `reply_to`' do
          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

          expected_prompt = <<~PROMPT.strip
            ---
            - id: #{other_human_message.api_id}
              user: #{other_human_message.user.first_name} (@#{other_human_message.user.username})
              text: #{other_human_message.text}
            - id: #{reply_to_human.api_id}
              user: #{human.first_name} (@#{human.username})
              text: #{reply_to_human.text}
              reply_to: #{other_human_message.api_id}
          PROMPT

          expect(LLMTools).to have_received(:chat_completion).with(
            system_prompt: anything,
            progress: an_instance_of(LLMProgress),
            messages: [{ role: 'user', content: expected_prompt }]
          )
        end
      end
    end

    context 'when message mentioning bot is NOT a reply to another message' do
      it 'adds nothing to YAML above user message' do
        older_msg = create(:message, chat:, date: 3.minutes.ago)

        described_class.perform_now(chat, TelegramTools.serialize_api_message(api_human_msg))

        expected_prompt = <<~PROMPT.strip
          ---
          - id: #{older_msg.api_id}
            user: #{older_msg.user.first_name} (@#{older_msg.user.username})
            text: #{older_msg.text}
          - id: #{human_message.api_id}
            user: #{human.first_name} (@#{human.username})
            text: #{human_message.text}
        PROMPT

        expect(LLMTools).to have_received(:chat_completion).with(
          system_prompt: anything,
          progress: an_instance_of(LLMProgress),
          messages: [{ role: 'user', content: expected_prompt }]
        )
      end
    end

    context 'when LLM output is blank' do
      before do
        allow(TelegramTools).to receive(:send_error_message)
        allow(LLMTools).to receive(:chat_completion)
          .and_return LLMTools::Completion.new(text: '', split_replies: false)
      end

      it 'raises error' do
        serialized_message = TelegramTools.serialize_api_message(api_reply_to_bot)

        expect do
          described_class.perform_now(chat, serialized_message)
        end.to raise_error(FuckyWuckies::ReplyJobFailure, /Blank LLM output/)
      end

      it 'does not send response message' do
        serialized_message = TelegramTools.serialize_api_message(api_reply_to_bot)

        expect do
          described_class.perform_now(chat, serialized_message)
        end.to raise_error(FuckyWuckies::ReplyJobFailure, /Blank LLM output/)

        expect(TelegramTools).not_to have_received(:send_error_message)
      end
    end

    context 'when LLM output is NOT blank' do
      it 'does not raise error' do
        serialized_message = TelegramTools.serialize_api_message(api_reply_to_bot)

        expect do
          described_class.perform_now(chat, serialized_message)
        end.not_to raise_error
      end
    end

    context 'when LLM reply generation successful' do
      it 'sends output in telegram reply to mention' do
        serialized_message = TelegramTools.serialize_api_message(api_reply_to_human)

        described_class.perform_now(chat, serialized_message)

        expect(Telegram.bot).to have_received(:send_message).with(
          chat_id: chat.api_id,
          protect_content: false,
          disable_notification: true,
          text: 'LLM generated reply text',
          reply_parameters: {
            message_id: reply_to_human.api_id,
            allow_sending_without_reply: true
          }
        )
      end

      context 'when model has split_replies enabled' do
        let(:multiline_text) { "lol no\n\nthat's a terrible idea\ndo it anyway" }

        before do
          allow_any_instance_of(described_class).to receive(:sleep)
          allow(LLMTools).to receive(:chat_completion)
            .and_return LLMTools::Completion.new(text: multiline_text, split_replies: true)
        end

        it 'sends each line as a separate message, only the first replying to the mention' do
          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

          expect(Telegram.bot).to have_received(:send_message).with(
            chat_id: chat.api_id,
            protect_content: false,
            disable_notification: true,
            text: 'lol no',
            reply_parameters: { message_id: reply_to_human.api_id, allow_sending_without_reply: true }
          ).ordered
          expect(Telegram.bot).to have_received(:send_message).with(
            chat_id: chat.api_id, protect_content: false, disable_notification: true, text: "that's a terrible idea"
          ).ordered
          expect(Telegram.bot).to have_received(:send_message).with(
            chat_id: chat.api_id, protect_content: false, disable_notification: true, text: 'do it anyway'
          ).ordered
          expect(Telegram.bot).to have_received(:send_message).exactly(3).times # blank line skipped
        end

        it 'pauses 1-3s before each follow-up message, but not the first' do
          sleeps = []
          allow_any_instance_of(described_class).to receive(:sleep) { |_job, seconds| sleeps << seconds }

          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

          expect(sleeps.size).to eq 2
          expect(sleeps).to all(be_between(1.0, 3.0))
        end

        it 'shows typing indicator before each follow-up message' do
          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

          expect(Telegram.bot).to have_received(:send_chat_action)
            .with(chat_id: chat.api_id, action: 'typing').twice
        end

        context 'when a message arrives while bot is "typing" follow-up messages' do
          let(:other_user_cu) { create(:chat_user, chat:) }

          # Simulates `message` being stored during the first pause between sent messages
          def run_with_message_during_pause(&create_message)
            sleeps = 0
            allow_any_instance_of(described_class).to receive(:sleep) do
              create_message.call if (sleeps += 1) == 1
            end
            described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))
          end

          shared_examples 'interrupted' do
            it 'stops sending, keeps only sent message in DB' do
              expect(Telegram.bot).to have_received(:send_message).once
              expect(Message.from_this_bot.pluck(:text)).to eq ['lol no']
            end
          end

          context 'when from the user being replied to' do
            before { run_with_message_during_pause { create(:message, chat_user: human_cu, text: 'wait what') } }

            it_behaves_like 'interrupted'
          end

          context 'when mentioning the bot' do
            before do
              run_with_message_during_pause do
                bot_username = Rails.application.credentials.telegram.bot.username
                create(:message, chat_user: other_user_cu, text: "hey @#{bot_username.upcase} shut up")
              end
            end

            it_behaves_like 'interrupted'
          end

          context "when replying to one of the bot's messages" do
            before do
              run_with_message_during_pause do
                create(:message, chat_user: other_user_cu, reply_to_message: Message.from_this_bot.last)
              end
            end

            it_behaves_like 'interrupted'
          end

          context 'when unrelated (another user talking to someone else)' do
            before { run_with_message_during_pause { create(:message, chat_user: other_user_cu, text: 'anyway') } }

            it 'sends all messages' do
              expect(Telegram.bot).to have_received(:send_message).exactly(3).times
            end
          end
        end

        context 'when a message from the user being replied to arrived before the first message was sent' do
          it 'sends all messages (bot was still generating, it had not "seen" it)' do
            allow(LLMTools).to receive(:chat_completion) do
              create(:message, chat_user: human_cu, text: 'hello??', date: Time.current)
              LLMTools::Completion.new(text: multiline_text, split_replies: true)
            end

            described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

            expect(Telegram.bot).to have_received(:send_message).exactly(3).times
          end
        end

        context 'with split limits' do
          def sent_texts(text)
            allow(LLMTools).to receive(:chat_completion)
              .and_return LLMTools::Completion.new(text:, split_replies: true)

            described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))
            telegram_sent_messages.pluck(:text)
          end

          it 'splits exactly MAX_SPLIT_MESSAGES lines' do
            lines = (1..described_class::MAX_SPLIT_MESSAGES).map { |i| "line #{i}" }
            expect(sent_texts(lines.join("\n"))).to eq lines
          end

          it 'does not split MAX_SPLIT_MESSAGES + 1 lines' do
            text = (1..(described_class::MAX_SPLIT_MESSAGES + 1)).map { |i| "line #{i}" }.join("\n")
            expect(sent_texts(text)).to eq [text]
          end

          it 'splits lines of exactly MAX_SPLIT_LINE_LENGTH' do
            lines = ['a' * described_class::MAX_SPLIT_LINE_LENGTH, 'short']
            expect(sent_texts(lines.join("\n"))).to eq lines
          end

          it 'does not split when any line is longer than MAX_SPLIT_LINE_LENGTH' do
            text = "#{'a' * (described_class::MAX_SPLIT_LINE_LENGTH + 1)}\nshort"
            expect(sent_texts(text)).to eq [text]
          end

          ['- bones', '* bones', '• bones', '1. bones', '2) bones'].each do |list_item|
            it "does not split list-like output (#{list_item.inspect})" do
              text = "snacks:\n#{list_item}"
              expect(sent_texts(text)).to eq [text]
            end
          end

          it 'sends single-line output as-is' do
            expect(sent_texts('just one line')).to eq ['just one line']
          end
        end

        it 'saves each message in DB' do
          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

          expect(Message.order(:id).last(3)).to match [
            have_attributes(text: 'lol no', reply_to_message: reply_to_human),
            have_attributes(text: "that's a terrible idea", reply_to_message: reply_to_human),
            have_attributes(text: 'do it anyway', reply_to_message: reply_to_human)
          ]
        end
      end

      context 'when the progress message was shown' do
        before do
          allow(Telegram.bot).to receive(:edit_message_text)
            .and_return({ 'ok' => true, 'result' => { 'message_id' => 555, 'date' => Time.current.to_i } })
          allow_any_instance_of(LLMProgress).to receive(:handover).and_return 555
          allow_any_instance_of(described_class).to receive(:sleep)
          allow(LLMTools).to receive(:chat_completion)
            .and_return LLMTools::Completion.new(text: "lol no\nthat's a terrible idea", split_replies: true)
        end

        it 'edits the first message into it, sends the rest as new messages' do
          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

          expect(Telegram.bot).to have_received(:edit_message_text).with(
            chat_id: chat.api_id, message_id: 555, text: 'lol no', reply_markup: { inline_keyboard: [] }
          )
          expect(telegram_sent_messages.pluck(:text)).to eq ["that's a terrible idea"]
          expect(Message.from_this_bot.order(:id).pluck(:api_id, :text))
            .to eq [[555, 'lol no'], [1_000_001, "that's a terrible idea"]]
        end
      end

      context 'when cancelled' do
        before { allow(LLMTools).to receive(:chat_completion).and_raise LLMProgress::Cancelled }

        it 'discards the job without sending anything' do
          expect do
            described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))
          end.not_to raise_error

          expect(Telegram.bot).not_to have_received(:send_message)
        end
      end

      context 'when model has split_replies disabled' do
        it 'sends multiline output as one message' do
          text = "lol no\nthat's a terrible idea"
          allow(LLMTools).to receive(:chat_completion)
            .and_return LLMTools::Completion.new(text:, split_replies: false)

          described_class.perform_now(chat, TelegramTools.serialize_api_message(api_reply_to_human))

          expect(Telegram.bot).to have_received(:send_message).once.with(hash_including(text:))
        end
      end

      it 'saves bot output as a Message in DB' do
        serialized_message = TelegramTools.serialize_api_message(api_reply_to_bot)

        described_class.perform_now(chat, serialized_message)

        expect(Message.last).to have_attributes(
          text: 'LLM generated reply text',
          chat_user: bot_cu
        )
      end
    end
  end

  describe 'conversation structure' do
    let(:llm_calls) { [] }
    let(:reply_text) { 'LLM generated reply text' }

    def api_message_for(db_message)
      Telegram::Bot::Types::Message.new(
        message_id: db_message.api_id,
        text: db_message.text,
        date: db_message.date,
        chat: Telegram::Bot::Types::Chat.new(id: chat.api_id, title: chat.title),
        from: Telegram::Bot::Types::User.new(
          id: db_message.user.api_id,
          is_bot: false,
          first_name: db_message.user.first_name,
          username: db_message.user.username
        )
      )
    end

    def reply_to(db_message)
      described_class.perform_now(chat, TelegramTools.serialize_api_message(api_message_for(db_message)))
      llm_calls.last
    end

    def user_turn_ids(turn)
      YAML.safe_load(turn[:content]).pluck('id')
    end

    before do
      allow_any_instance_of(described_class).to receive(:sleep)
      allow(LLMTools).to receive(:chat_completion) do |messages:, **|
        llm_calls << messages
        LLMTools::Completion.new(text: reply_text, split_replies: true)
      end
    end

    it 'puts bot replies right after the message they replied to, even if others were sent meanwhile' do
      human_cu
      bot_cu
      msg_a = create(:message, chat_user: human_cu, date: 5.minutes.ago)
      mention1 = create(:message, chat_user: human_cu, date: 4.minutes.ago)
      msg_b = create(:message, chat_user: human_cu, date: 3.minutes.ago) # sent while bot was generating
      bot_reply = create(:message, chat_user: bot_cu, reply_to_message: mention1, date: 2.minutes.ago)
      mention2 = create(:message, chat_user: human_cu, date: 1.minute.ago)

      messages = reply_to(mention2)

      expect(messages.pluck(:role)).to eq %w[user assistant user]
      expect(user_turn_ids(messages[0])).to eq [msg_a.api_id, mention1.api_id]
      expect(messages[1][:content]).to eq bot_reply.text
      expect(user_turn_ids(messages[2])).to eq [msg_b.api_id, mention2.api_id]
    end

    it 'joins consecutive bot messages (split replies) into one assistant turn' do
      human_cu
      bot_cu
      mention1 = create(:message, chat_user: human_cu, date: 4.minutes.ago)
      create(:message, chat_user: bot_cu, reply_to_message: mention1, text: 'lol', date: 3.minutes.ago)
      create(:message, chat_user: bot_cu, reply_to_message: mention1, text: 'no', date: 2.minutes.ago)
      mention2 = create(:message, chat_user: human_cu, date: 1.minute.ago)

      messages = reply_to(mention2)

      expect(messages[1]).to eq({ role: 'assistant', content: "lol\nno" })
    end

    it "makes previous prompt + bot's reply an exact prefix of the next prompt" do
      human_cu
      create_list(:message, 5, chat_user: human_cu, date: 10.minutes.ago)
      mention1 = create(:message, chat_user: human_cu, date: 2.minutes.ago)
      allow(LLMTools).to receive(:chat_completion) do |messages:, **|
        llm_calls << messages
        LLMTools::Completion.new(text: "lol no\nthat's a terrible idea", split_replies: true)
      end

      first_prompt = reply_to(mention1)
      create(:message, chat_user: human_cu, date: 1.minute.ago) # sent while bot was generating
      second_prompt = reply_to(create(:message, chat_user: human_cu, date: 1.minute.from_now))

      expect(second_prompt.first(first_prompt.size + 1)).to eq [
        *first_prompt,
        { role: 'assistant', content: "lol no\nthat's a terrible idea" }
      ]
    end

    it 'puts bot messages that are not replies (summaries etc) in date order, even as the first turn' do
      human_cu
      bot_cu
      summary = create(:message, chat_user: bot_cu, text: 'summary text', date: 3.minutes.ago)
      msg_a = create(:message, chat_user: human_cu, date: 2.minutes.ago)
      translation = create(:message, chat_user: bot_cu, text: 'translation text', date: 90.seconds.ago)
      mention = create(:message, chat_user: human_cu, date: 1.minute.ago)

      messages = reply_to(mention)

      expect(messages.pluck(:role)).to eq %w[assistant user assistant user]
      expect(messages[0][:content]).to eq summary.text
      expect(user_turn_ids(messages[1])).to eq [msg_a.api_id]
      expect(messages[2][:content]).to eq translation.text
      expect(user_turn_ids(messages[3])).to eq [mention.api_id]
    end

    describe 'messages sent in the same second as the mention' do
      let(:date) { 1.minute.ago.change(usec: 0) }

      it 'includes ones stored before the mention, excludes ones stored after it' do
        human_cu
        before_mention = create(:message, chat_user: human_cu, date:)
        mention = create(:message, chat_user: human_cu, date:)
        after_mention = create(:message, chat_user: human_cu, date:)

        ids = user_turn_ids(reply_to(mention).last)

        expect(ids).to eq [before_mention.api_id, mention.api_id]
        expect(ids).not_to include after_mention.api_id
      end
    end

    describe 'context window' do
      def create_history(count)
        (1..count).map { |i| create(:message, chat_user: human_cu, date: 1.day.ago + i.seconds) }
      end

      it 'includes all messages while there are fewer than CONTEXT_MIN_MESSAGES + CONTEXT_STEP' do
        history = create_history(149)
        mention = create(:message, chat_user: human_cu, date: Time.current)

        ids = user_turn_ids(reply_to(mention).last)

        expect(ids.size).to eq 150
        expect(ids.first).to eq history.first.api_id
      end

      it 'moves window start forward by CONTEXT_STEP once enough messages accumulate' do
        history = create_history(150)
        mention = create(:message, chat_user: human_cu, date: Time.current)

        ids = user_turn_ids(reply_to(mention).last)

        expect(ids.size).to eq 101
        expect(ids.first).to eq history[50].api_id
      end
    end
  end
end
