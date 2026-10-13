# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DraftStreamer do
  let(:chat) { create(:chat, api_type: :private_room) }
  let(:requests) { [] }
  let!(:bot) do
    stub_telegram_bot.tap do |bot|
      allow(bot).to receive(:request) { |action, params| requests << [action, params] }
    end
  end
  let(:streamer) { described_class.new(chat) }
  let(:t0) { Time.zone.parse('2026-10-11 12:00:00') }

  after { described_class::REGISTRY.clear }

  def drafts = requests.map { |action, params| [action, params[:text]] }

  describe '#tick' do
    it 'shows "Thinking…" (empty text) right away, with a stop button' do
      streamer.tick(t0)

      expect(bot).to have_received(:request).with(
        :sendMessageDraft, chat_id: chat.api_id, draft_id: a_value > 0, text: '', can_stop: true, keep_on_stop: true
      )
    end

    it 'updates with the output so far at most every UPDATE_INTERVAL' do
      streamer.tick(t0)
      streamer.llm_output('Hello')
      streamer.tick(t0 + 0.5) # too soon
      streamer.tick(t0 + described_class::UPDATE_INTERVAL)
      streamer.llm_output(' there')
      streamer.tick(t0 + (described_class::UPDATE_INTERVAL * 2))

      expect(drafts).to eq [[:sendMessageDraft, ''], [:sendMessageDraft, 'Hello'], [:sendMessageDraft, 'Hello there']]
    end

    it "re-sends an unchanged draft before it expires, but doesn't spam it" do
      streamer.tick(t0)
      streamer.tick(t0 + described_class::UPDATE_INTERVAL)
      streamer.tick(t0 + described_class::REFRESH_INTERVAL)

      expect(drafts.size).to eq 2
    end

    it 'ignores thinking, and starts over when generation restarts' do
      streamer.llm_thinking('hmm')
      streamer.llm_output('first try')
      streamer.llm_started(nil, [])

      expect(streamer.text).to eq ''
    end
  end

  describe '.stop' do
    it 'raises Stopped in the thread generating the reply' do
      job_thread = Thread.new do
        streamer = described_class.new(chat)
        streamer.start
        sleep 5
        :not_stopped
      rescue DraftStreamer::Stopped
        :stopped
      ensure
        streamer&.finish
      end
      sleep 0.1 until described_class::REGISTRY.key?(chat.api_id)

      described_class.stop(chat.api_id)

      expect(job_thread.value).to eq :stopped
    end

    it 'does nothing when nothing is being streamed in the chat, or it finished' do
      streamer.start
      streamer.finish

      expect { described_class.stop(chat.api_id) }.not_to raise_error
      expect { streamer.stop }.not_to raise_error
    end
  end
end
