# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::DescribeStickerJob do
  let(:model) { 'local-model' }

  def perform = described_class.perform_now('sticker_uid', 'sticker_file_id', '🙂')

  before do
    allow(LocalInferenceApi).to receive_messages(available_model: model, vision?: true,
                                                 run_chat_completion: " a shiba inu\n shrugging ")
    allow(TelegramTools).to receive(:download_file).and_return 'webp bytes'
  end

  it "saves the model's description of the sticker's image" do
    expect { perform }.to change(StickerDescription, :count).by(1)

    expect(StickerDescription.last).to have_attributes(file_unique_id: 'sticker_uid',
                                                       description: 'a shiba inu shrugging')
    expect(TelegramTools).to have_received(:download_file).with('sticker_file_id')
  end

  it 'sends the image with its emoji, without thinking' do
    perform

    expect(LocalInferenceApi).to have_received(:run_chat_completion) do |model:, messages:, request_params:, **|
      expect(model).to eq 'local-model'
      expect(messages).to match [{ role: 'user', content: include('emoji: 🙂'),
                                   images: [Base64.strict_encode64('webp bytes')] }]
      expect(request_params).to eq(think: false)
    end
  end

  it 'does nothing when the sticker already has a description' do
    StickerDescription.create!(file_unique_id: 'sticker_uid', description: 'old')

    expect { perform }.not_to change(StickerDescription, :count)
    expect(TelegramTools).not_to have_received(:download_file)
  end

  it 'skips when the local model is unavailable' do
    allow(LocalInferenceApi).to receive(:available_model).and_return nil

    expect { perform }.not_to change(StickerDescription, :count)
    expect(TelegramTools).not_to have_received(:download_file)
  end

  it "skips when the local model can't see images" do
    allow(LocalInferenceApi).to receive(:vision?).and_return false

    expect { perform }.not_to change(StickerDescription, :count)
  end

  it 'skips when the download fails' do
    allow(TelegramTools).to receive(:download_file).and_raise Telegram::Bot::Error, 'nope'

    expect { perform }.not_to change(StickerDescription, :count)
  end

  it 'marks the local model unavailable when its request fails' do
    allow(LocalInferenceApi).to receive(:run_chat_completion).and_raise Faraday::ConnectionFailed
    allow(LocalInferenceApi).to receive(:mark_unavailable!)

    expect { perform }.not_to change(StickerDescription, :count)
    expect(LocalInferenceApi).to have_received(:mark_unavailable!).with(an_instance_of(Faraday::ConnectionFailed))
  end

  it 'does not save a blank description' do
    allow(LocalInferenceApi).to receive(:run_chat_completion).and_return ''

    expect { perform }.not_to change(StickerDescription, :count)
  end

  it 'ignores the sticker having been described meanwhile' do
    allow(LocalInferenceApi).to receive(:run_chat_completion) do
      StickerDescription.create!(file_unique_id: 'sticker_uid', description: 'described meanwhile')
      'a shiba inu'
    end

    expect { perform }.not_to raise_error
    expect(StickerDescription.pluck(:description)).to eq ['described meanwhile']
  end
end
