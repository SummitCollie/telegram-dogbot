# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::DirectReplyJob do
  include ActiveJob::TestHelper

  let(:user) { create_premium_user(first_name: 'Sam') }
  let(:chat) { private_chat_for(user) }
  let(:user_cu) { create(:chat_user, chat:, user:) }
  let(:bot_cu) { create(:chat_user, chat:, user: create(:user, is_this_bot: true)) }
  let!(:earlier) { create(:message, chat_user: user_cu, text: 'hey', date: 3.minutes.ago) }
  let!(:earlier_reply) do
    create(:message, chat_user: bot_cu, text: 'sup', date: 2.minutes.ago, reply_to_message: earlier)
  end
  let!(:message) { create(:message, chat_user: user_cu, text: 'how are you', date: 1.minute.ago) }
  let(:completion) { LLMTools::Completion.new(text: 'great thanks', split_replies: false) }

  before do
    stub_telegram_bot
    allow(LLMTools).to receive(:chat_completion).and_return(completion)
    allow_any_instance_of(DraftStreamer).to receive(:start)
    allow(described_class).to receive(:sleep)
    allow_any_instance_of(described_class).to receive(:sleep)
  end

  after { described_class::NAP_NOTICES.clear }

  it 'replies in the persona from their settings, using only the local LLM' do
    user.dm_setting.update!(bot_name: 'Rex', creativity: 4)

    described_class.perform_now(message)

    expect(LLMTools).to have_received(:chat_completion).with(
      system_prompt: a_string_starting_with('You are Rex, texting one-on-one with Sam'),
      messages: [
        { role: 'user', content: 'hey' },
        { role: 'assistant', content: 'sup' },
        { role: 'user', content: 'how are you' }
      ],
      model_params: { temperature: DmSetting::TEMPERATURES[4] },
      progress: an_instance_of(DraftStreamer),
      local_only: true
    )
    expect(telegram_sent_messages).to contain_exactly(
      { chat_id: chat.api_id, text: 'great thanks', protect_content: false }
    )
    expect(chat.messages.from_this_bot.last).to have_attributes(text: 'great thanks', reply_to_message: message)
  end

  it 'quotes what replies are replying to, and marks attachments' do
    message.update!(reply_to_message: earlier_reply, attachment_type: :photo)

    described_class.perform_now(message)

    expected_turn = { role: 'user', content: '[photo] (replying to you: "sup") how are you' }
    expect(LLMTools).to have_received(:chat_completion)
      .with(hash_including(messages: a_collection_including(expected_turn)))
  end

  it "doesn't collapse long replies like in groups" do
    long = Array.new(8) { |i| "line number #{i} of a long answer" }.join("\n")
    allow(LLMTools).to receive(:chat_completion).and_return(LLMTools::Completion.new(text: long, split_replies: false))
    user.dm_setting.update!(double_texting: false)

    described_class.perform_now(message)

    expect(telegram_sent_messages.sole).to include(text: long)
    expect(telegram_sent_messages.sole).not_to have_key(:parse_mode)
  end

  it 'double-texts when enabled' do
    allow(LLMTools).to receive(:chat_completion)
      .and_return(LLMTools::Completion.new(text: "great thanks\nhow about you", split_replies: false))

    described_class.perform_now(message)
    expect(telegram_sent_messages.pluck(:text)).to eq ['great thanks', 'how about you']

    telegram_sent_messages.clear
    user.dm_setting.update!(double_texting: false)
    later = create(:message, chat_user: user_cu, text: 'cool')
    described_class.perform_now(later)
    expect(telegram_sent_messages.pluck(:text)).to eq ["great thanks\nhow about you"]
  end

  it "skips messages that a newer message's job will reply to" do
    create(:message, chat_user: user_cu, text: 'also')

    described_class.perform_now(message)

    expect(LLMTools).not_to have_received(:chat_completion)
  end

  it 'skips users who are no longer premium' do
    user.star_payments.update_all(refunded_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    described_class.perform_now(message)

    expect(LLMTools).not_to have_received(:chat_completion)
  end

  it 'is enqueued after a short delay, so a burst of messages gets one reply' do
    expect { described_class.enqueue(message) }.to have_enqueued_job(described_class)
      .with(message).at(a_value_within(1.second).of(described_class::DEBOUNCE.from_now))
  end

  context 'when the local LLM is down' do
    before { allow(LLMTools).to receive(:chat_completion).and_raise(FuckyWuckies::LocalLLMUnavailable.new) }

    it 'says it is napping (once in a while) and retries later' do
      expect { described_class.perform_now(message) }.to have_enqueued_job(described_class)
      expect { described_class.perform_now(message) }.to have_enqueued_job(described_class)

      expect(telegram_sent_messages.sole).to include(chat_id: chat.api_id, text: a_string_including("brain's offline"))
      expect(chat.messages.from_this_bot.count).to eq 1 # notices aren't part of the conversation
    end

    it 'gives up after a while' do
      described_class.perform_later(message)
      described_class::RETRY_ATTEMPTS.times { perform_enqueued_jobs } # each retry enqueues the next

      expect(LLMTools).to have_received(:chat_completion).exactly(described_class::RETRY_ATTEMPTS).times
      expect(telegram_sent_messages.pluck(:text)).to match [
        a_string_including("brain's offline"), a_string_including('still offline')
      ]
    end
  end

  context 'when the user presses stop' do
    it 'keeps what was written so far' do
      allow_any_instance_of(DraftStreamer).to receive(:text).and_return('great')
      allow(LLMTools).to receive(:chat_completion).and_raise(DraftStreamer::Stopped)

      described_class.perform_now(message)

      expect(telegram_sent_messages.pluck(:text)).to eq ['great']
    end

    it 'sends nothing if nothing was written yet' do
      allow(LLMTools).to receive(:chat_completion).and_raise(DraftStreamer::Stopped)

      described_class.perform_now(message)

      expect(telegram_sent_messages).to be_empty
    end
  end
end
