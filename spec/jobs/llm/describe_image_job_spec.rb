# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::DescribeImageJob do
  let(:photo) do
    create(:message, attachment_type: :photo, image_file_id: 'photo_file_id', image_status: :pending,
                     text: 'my new car')
  end
  let(:sticker) do
    create(:message, attachment_type: :sticker, image_file_id: 'sticker_file_id', image_status: :pending,
                     sticker_file_unique_id: 'sticker_uid', text: '🙂 (slightly smiling face)')
  end

  def perform(message) = described_class.perform_now(message.id)

  before do
    stub_const("#{described_class}::RETRY_DELAY", 0)
    allow(LocalInferenceApi).to receive_messages(available_model: 'local-model', vision?: true,
                                                 run_chat_completion: " a red\n sports car ")
    allow(TelegramTools).to receive(:download_file).and_return 'image bytes'
    allow(ImageDescriptions).to receive(:finished).and_call_original
  end

  it "saves the model's description, and the photo" do
    perform(photo)

    expect(photo.reload).to have_attributes(image_status: 'described', image_description: 'a red sports car')
    expect(photo.image.data).to eq 'image bytes'
    expect(TelegramTools).to have_received(:download_file).with('photo_file_id')
  end

  it 'sends the image with its caption for context, without thinking' do
    perform(photo)

    expect(LocalInferenceApi).to have_received(:run_chat_completion) do |model:, messages:, request_params:, **|
      expect(model).to eq 'local-model'
      expect(messages).to match [{ role: 'user',
                                   content: include('Text: "..."').and(include('caption, for context: my new car')),
                                   images: [Base64.strict_encode64('image bytes')] }]
      expect(request_params).to eq(think: false)
    end
  end

  it 'tells ImageDescriptions when done' do
    perform(photo)

    expect(ImageDescriptions).to have_received(:finished).with(photo.id)
  end

  it 'uses the stored photo rather than downloading it again' do
    photo.create_image!(data: 'stored bytes')

    perform(photo)

    expect(TelegramTools).not_to have_received(:download_file)
    expect(LocalInferenceApi).to have_received(:run_chat_completion)
      .with(hash_including(messages: [hash_including(images: [Base64.strict_encode64('stored bytes')])]))
  end

  it 'does nothing for messages that are already described' do
    photo.update!(image_status: :described)

    perform(photo)

    expect(TelegramTools).not_to have_received(:download_file)
    expect(ImageDescriptions).to have_received(:finished).with(photo.id)
  end

  describe 'images sent as files' do
    let(:document) do
      create(:message, attachment_type: :document, image_file_id: 'doc_file_id', image_status: :pending, text: nil)
    end

    it 'stores them shrunk, and describes that' do
      allow(TelegramTools).to receive(:compress_image).with('image bytes').and_return 'small jpeg'

      perform(document)

      expect(document.reload).to have_attributes(image_status: 'described', image_description: 'a red sports car')
      expect(document.image.data).to eq 'small jpeg'
      expect(LocalInferenceApi).to have_received(:run_chat_completion)
        .with(hash_including(messages: [hash_including(images: [Base64.strict_encode64('small jpeg')])]))
    end

    it "marks them failed, without retrying, when they're not images libvips can read" do
      perform(document)

      expect(document.reload.image_status).to eq 'failed'
      expect(TelegramTools).to have_received(:download_file).once
      expect(ImageDescriptions).to have_received(:finished).with(document.id)
    end
  end

  describe 'stickers' do
    it 'describes them once, without storing their image' do
      perform(sticker)

      expect(sticker.reload).to have_attributes(image_status: 'described', image_description: 'a red sports car')
      expect(sticker.image).to be_nil
      expect(StickerDescription.find_by(file_unique_id: 'sticker_uid').description).to eq 'a red sports car'
      expect(LocalInferenceApi).to have_received(:run_chat_completion)
        .with(hash_including(messages: [hash_including(content: include('Its emoji: 🙂'))]))
    end

    it 'reuses the description from when the sticker was sent before' do
      StickerDescription.create!(file_unique_id: 'sticker_uid', description: 'a dog smiling')

      perform(sticker)

      expect(sticker.reload).to have_attributes(image_status: 'described', image_description: 'a dog smiling')
      expect(TelegramTools).not_to have_received(:download_file)
      expect(LocalInferenceApi).not_to have_received(:run_chat_completion)
    end
  end

  shared_examples 'leaves it pending' do
    it 'leaves it pending, but keeps the downloaded photo' do
      perform(photo)

      expect(photo.reload).to have_attributes(image_status: 'pending', image_description: nil)
      expect(photo.image.data).to eq 'image bytes'
      expect(ImageDescriptions).to have_received(:finished).with(photo.id)
    end
  end

  context 'when the self-hosted model is unavailable' do
    before { allow(LocalInferenceApi).to receive(:available_model).and_return nil }

    it_behaves_like 'leaves it pending'
  end

  context "when the self-hosted model can't see images" do
    before { allow(LocalInferenceApi).to receive(:vision?).and_return false }

    it_behaves_like 'leaves it pending'
  end

  context 'when the self-hosted model fails' do
    before do
      allow(LocalInferenceApi).to receive(:run_chat_completion).and_raise Faraday::ConnectionFailed, 'down'
      allow(LocalInferenceApi).to receive(:mark_unavailable!)
    end

    it_behaves_like 'leaves it pending'

    it 'marks it unavailable' do
      perform(photo)

      expect(LocalInferenceApi).to have_received(:mark_unavailable!)
    end
  end

  describe 'retries' do
    it 'retries failed downloads' do
      attempts = 0
      allow(TelegramTools).to receive(:download_file) do
        (attempts += 1) < 3 ? raise(Telegram::Bot::Error, 'timeout') : 'image bytes'
      end

      perform(photo)

      expect(photo.reload.image_status).to eq 'described'
    end

    it 'retries blank descriptions, without downloading again' do
      allow(LocalInferenceApi).to receive(:run_chat_completion).and_return("  \n", 'a cat')

      perform(photo)

      expect(photo.reload).to have_attributes(image_status: 'described', image_description: 'a cat')
      expect(TelegramTools).to have_received(:download_file).once
    end

    it "marks it failed when the image still can't be downloaded after MAX_ATTEMPTS" do
      allow(TelegramTools).to receive(:download_file).and_raise Telegram::Bot::Error, 'gone'

      perform(photo)

      expect(photo.reload.image_status).to eq 'failed'
      expect(TelegramTools).to have_received(:download_file).exactly(described_class::MAX_ATTEMPTS).times
      expect(ImageDescriptions).to have_received(:finished).with(photo.id).once
    end

    it 'marks it failed when the description is still blank after MAX_ATTEMPTS' do
      allow(LocalInferenceApi).to receive(:run_chat_completion).and_return "  \n"

      perform(photo)

      expect(photo.reload).to have_attributes(image_status: 'failed', image_description: nil)
      expect(LocalInferenceApi).to have_received(:run_chat_completion).exactly(described_class::MAX_ATTEMPTS).times
    end
  end
end
