# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImageDescriptions do
  include ActiveJob::TestHelper

  let(:pending) { create_list(:message, 2, attachment_type: :photo, image_status: :pending) }
  let(:described) { create(:message, attachment_type: :photo, image_status: :described) }

  describe '.request' do
    it 'queues describing pending images, and returns their ids' do
      expect(described_class.request([*pending, described, nil])).to eq pending.map(&:id)

      expect(LLM::DescribeImageJob).to have_been_enqueued.exactly(2).times
    end

    it "doesn't queue images that are already queued" do
      described_class.request(pending)
      described_class.request(pending)

      expect(LLM::DescribeImageJob).to have_been_enqueued.exactly(2).times
    end

    it 'queues them again once finished' do
      described_class.request(pending)
      described_class.finished(pending.first.id)
      described_class.request(pending)

      expect(LLM::DescribeImageJob).to have_been_enqueued.with(pending.first.id).twice
    end
  end

  describe '.wait_for' do
    it 'returns once all the images are finished, reporting how many are left' do
      described_class.request(pending)
      reports = []

      waiter = Thread.new { described_class.wait_for(pending.map(&:id)) { |left| reports << left } }
      sleep 0.05 until waiter.stop?
      described_class.finished(pending.first.id)
      sleep 0.05 until reports.size == 2 && waiter.stop?
      described_class.finished(pending.last.id)

      expect(waiter.join(2)).to be_truthy
      expect(reports).to eq [2, 1, 0]
    end

    it "returns right away when they aren't being described" do
      expect { |block| described_class.wait_for([described.id], &block) }.to yield_with_args(0)
    end
  end
end
