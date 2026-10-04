# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLMProgress do
  let(:chat) { create(:chat) }
  let(:mention) { create(:message, chat:) }
  let(:requester) { mention.user }
  let(:t0) { Time.zone.parse('2026-10-05 12:00:00') }
  let!(:bot) { stub_telegram_bot(send_chat_action: true, edit_message_text: true, delete_message: true) }
  let(:progress) do
    described_class.new(chat, label: 'a reply', reply_to: mention, requester: requester.api_id, now: t0)
  end
  let(:local_provider) do
    LLMTools::Provider.new(model: 'hf.co/someone/Some-Model-GGUF:Q6_K', self_hosted: true, split_replies: true)
  end
  let(:cloud_provider) { LLMTools::Provider.new(model: 'llama-3.3-70b', self_hosted: false, split_replies: false) }
  let(:prompt) { [{ role: 'system', content: 'a' * 350 }, { role: 'user', content: 'b' * 3150 }] } # ~1k tokens

  before do
    allow(LocalInferenceApi).to receive_messages(loaded_model: nil, prompt_tokens_per_second: nil)
  end

  after { described_class::REGISTRY.clear }

  def sent_tracker = telegram_sent_messages.last

  describe '#tick' do
    it 'only shows typing before SHOW_AFTER, at most every TYPING_INTERVAL' do
      progress.tick(t0)
      progress.tick(t0 + 1)
      progress.tick(t0 + described_class::TYPING_INTERVAL)

      expect(bot).to have_received(:send_chat_action).with(chat_id: chat.api_id, action: 'typing').twice
      expect(bot).not_to have_received(:send_message)
    end

    it 'sends a silent progress message with a cancel button after SHOW_AFTER, replying to the mention' do
      progress.tick(t0 + described_class::SHOW_AFTER)

      expect(sent_tracker).to include(
        chat_id: chat.api_id, parse_mode: 'HTML', disable_notification: true,
        reply_markup: described_class::CANCEL_KEYBOARD,
        reply_parameters: { message_id: mention.api_id, allow_sending_without_reply: true }
      )
      expect(sent_tracker[:text]).to start_with '🐶 <b>Working on a reply…</b> 5s'
    end

    it 'edits progress message at most every UPDATE_INTERVAL, only when it changed' do
      progress.tick(t0 + 5)
      progress.tick(t0 + 6) # too soon
      progress.tick(t0 + 5 + described_class::UPDATE_INTERVAL)

      expect(bot).to have_received(:edit_message_text).once.with(
        chat_id: chat.api_id, message_id: 1_000_001, parse_mode: 'HTML', reply_markup: described_class::CANCEL_KEYBOARD,
        text: a_string_including('8s')
      )
    end

    it 'does not edit when nothing changed' do
      allow(progress).to receive(:render).and_return 'same'

      progress.tick(t0 + 5)
      progress.tick(t0 + 10)

      expect(bot).not_to have_received(:edit_message_text)
    end

    it 'stops trying to send the progress message if sending fails' do
      allow(bot).to receive(:send_message).and_raise Telegram::Bot::Error

      progress.tick(t0 + 5)
      progress.tick(t0 + 6)

      expect(bot).to have_received(:send_message).once
      expect(bot).to have_received(:send_chat_action).at_least(:once)
    end
  end

  describe '#render' do
    def lines(now) = progress.render(now).lines.map(&:chomp)

    it 'shows getting ready before the LLM request starts' do
      expect(lines(t0 + 6)[1]).to eq '⏳ Getting ready… 6s'
    end

    context 'with a cloud provider' do
      before { progress.llm_started(cloud_provider, prompt, now: t0 + 1) }

      it 'shows reading messages, with estimated prompt size' do
        expect(lines(t0 + 6)).to eq [
          '🐶 <b>Working on a reply…</b> 6s',
          '⏳ Read messages · ~1k tokens',
          '▫️ Write reply',
          '<i>llama-3.3-70b</i>'
        ]
      end

      it 'shows output tokens and speed while writing' do
        progress.llm_output('a', now: t0 + 7)
        20.times { progress.llm_output('b', now: t0 + 8) }

        expect(lines(t0 + 9)[1..2]).to eq ['✅ Read messages · 6s', '⏳ Write reply · 21 tokens · 10.5 tok/s']
      end
    end

    context 'with a self-hosted provider' do
      before do
        allow(LocalInferenceApi).to receive(:config).and_return(
          ActiveSupport::OrderedOptions[request_params: { options: { num_ctx: 32768 } }]
        )
        progress.llm_started(local_provider, prompt, now: t0 + 1)
      end

      it 'shows waking up the model while it is not loaded' do
        progress.tick(t0 + 2)

        expect(lines(t0 + 6)[1..3]).to eq ['⏳ Wake up model · 5s', '▫️ Read messages', '▫️ Write reply']
        expect(lines(t0 + 6).last).to eq '<i>Some-Model-GGUF:Q6_K · 32k context</i>'
      end

      it 'moves on once the model is loaded, showing its context size and an ETA' do
        allow(LocalInferenceApi).to receive_messages(
          prompt_tokens_per_second: 100.0,
          loaded_model: { 'name' => local_provider.model, 'context_length' => 16384 }
        )
        progress.tick(t0 + 2) # first check finds it loaded

        expect(lines(t0 + 4)).to eq [
          '🐶 <b>Working on a reply…</b> 4s',
          '✅ Wake up model · already awake',
          '⏳ Read messages · ~1k tokens · up to ~8s left',
          '▫️ Write reply',
          '<i>Some-Model-GGUF:Q6_K · 16k context</i>'
        ]
        expect(lines(t0 + 20)[2]).to eq '⏳ Read messages · ~1k tokens · any second now'
      end

      it 'shows how long the model took to wake up, checking every MODEL_CHECK_INTERVAL' do
        progress.tick(t0 + 2)
        allow(LocalInferenceApi).to receive(:loaded_model).and_return({ 'name' => local_provider.model })
        progress.tick(t0 + 3) # too soon to check again
        expect(lines(t0 + 3)[1]).to start_with '⏳ Wake up model'

        progress.tick(t0 + 2 + described_class::MODEL_CHECK_INTERVAL)
        expect(lines(t0 + 5)[1]).to eq '✅ Wake up model · 3s'
        expect(LocalInferenceApi).to have_received(:loaded_model).twice
      end
    end

    it 'escapes HTML in the label and model name' do
      progress = described_class.new(chat, label: 'a <b>', now: t0)
      progress.llm_started(cloud_provider.with(model: 'm<x>'), prompt, now: t0)

      expect(progress.render(t0)).to include('a &lt;b&gt;', 'm&lt;x&gt;')
    end
  end

  describe '#handover and #finish' do
    it 'deletes the progress message on finish' do
      progress.tick(t0 + 5)
      progress.finish

      expect(bot).to have_received(:delete_message).with(chat_id: chat.api_id, message_id: 1_000_001)
      expect(described_class::REGISTRY).to be_empty
    end

    it 'hands over the progress message instead of deleting it' do
      progress.tick(t0 + 5)

      expect(progress.handover).to eq 1_000_001
      progress.finish

      expect(bot).not_to have_received(:delete_message)
      expect(described_class::REGISTRY).to be_empty
    end

    it 'hands over nothing when the progress message was never shown' do
      progress.tick(t0 + 1)

      expect(progress.handover).to be_nil
      progress.finish
      expect(bot).not_to have_received(:delete_message)
    end
  end

  describe 'cancelling' do
    let(:job_thread) { Thread.new { sleep } }
    let(:progress) do
      described_class.new(chat, label: 'a reply', reply_to: mention, requester: requester.api_id, now: t0)
                     .tap { |p| p.instance_variable_set(:@job_thread, job_thread) }
    end

    def press_cancel(user)
      described_class.cancel(chat_api_id: chat.api_id, message_id: 1_000_001,
                             from: Telegram::Bot::Types::User.new(id: user.api_id, is_bot: false,
                                                                  first_name: 'x', username: user.username))
    end

    before { progress.tick(t0 + 5) }
    after { job_thread.kill }

    it 'raises Cancelled in the job thread when the requester presses cancel' do
      expect(press_cancel(requester)).to eq 'Cancelled'
      expect { job_thread.join(2) }.to raise_error(described_class::Cancelled, /Cancelled by @/)
    end

    it "lets the bot's owner cancel" do
      owner = build(:user, username: Rails.application.credentials.telegram.bot.owner_username)

      expect(press_cancel(owner)).to eq 'Cancelled'
    end

    it 'refuses anyone else' do
      expect(press_cancel(create(:user))).to start_with 'Only whoever asked'
      expect(job_thread).to be_alive
    end

    it 'lets anyone cancel when there is no requester' do
      progress.instance_variable_set(:@requester, nil)

      expect(press_cancel(create(:user))).to eq 'Cancelled'
    end

    it 'is too late once finished' do
      progress.handover

      expect(press_cancel(requester)).to eq 'Too late, already done'
      expect(job_thread).to be_alive
    end

    it 'deletes progress messages it does not know about (e.g. left over from a restart)' do
      described_class::REGISTRY.clear

      expect(press_cancel(requester)).to eq 'Already finished'
      expect(bot).to have_received(:delete_message).with(chat_id: chat.api_id, message_id: 1_000_001)
    end
  end

  describe '.track' do
    before { allow(described_class).to receive(:track).and_call_original }

    it 'runs the updater thread, and cleans up afterwards' do
      stub_const("#{described_class}::SHOW_AFTER", 0)

      described_class.track(chat, label: 'a summary') do |progress|
        sleep 0.1 until progress.instance_variable_get(:@message_id)
      end

      expect(sent_tracker[:text]).to include 'Working on a summary'
      expect(bot).to have_received(:delete_message).with(chat_id: chat.api_id, message_id: 1_000_001)
    end

    it 'still cleans up when the block is cancelled' do
      stub_const("#{described_class}::SHOW_AFTER", 0)

      expect do
        described_class.track(chat, label: 'a summary') do |progress|
          sleep 0.1 until progress.instance_variable_get(:@message_id)
          raise described_class::Cancelled
        end
      end.to raise_error described_class::Cancelled
      expect(bot).to have_received(:delete_message)
    end
  end
end
