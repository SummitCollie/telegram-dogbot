# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLMTools do
  describe '.messages_to_yaml' do
    it 'contains all input messages' do
      chat = create(:chat)
      messages = Array.new(250) do
        create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
      end.sort_by(&:date)

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.size).to eq messages.size
    end

    it 'correctly sets id/user/text' do
      chat = create(:chat)
      messages = Array.new(250) do
        create(:message, chat:, date: Faker::Time.unique.backward(days: 2))
      end.sort_by(&:date)

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.first[:id]).to eq messages.first.api_id
      expect(results.first[:user]).to eq messages.first.user.first_name
      expect(results.first[:text]).to eq messages.first.text

      expect(results.last[:id]).to eq messages.last.api_id
      expect(results.last[:user]).to eq messages.last.user.first_name
      expect(results.last[:text]).to eq messages.last.text
    end

    it 'sets `reply_to` when parent message within context' do
      chat = create(:chat)
      parent_message = create(:message, chat:, date: 2.minutes.ago)
      response_message = create(:message, chat:, date: 1.minute.ago, reply_to_message: parent_message)
      messages = [parent_message, response_message]

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.last[:reply_to]).to eq messages.first.api_id
    end

    it 'omits `reply_to` when parent message outside of context' do
      chat = create(:chat)
      parent_message = create(:message, chat:, date: 3.minutes.ago)
      response_message = create(:message, chat:, date: 2.minutes.ago, reply_to_message: parent_message)
      create(:message, chat:, date: 1.minute.ago)
      messages = [response_message, response_message]

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.last.key?(:reply_to)).to be false
    end

    it 'sets `attachment_type` for messages with attachments' do
      chat = create(:chat)
      message_w_photo = create(:message, chat:, date: 2.hours.ago, attachment_type: :photo)
      message_no_photo = create(:message, chat:, date: 1.hour.ago)
      messages = [message_w_photo, message_no_photo]

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.first[:attachment]).to eq 'photo'
    end

    it 'omits `attachment_type` for messages without attachments' do
      chat = create(:chat)
      message_w_photo = create(:message, chat:, date: 2.hours.ago, attachment_type: :photo)
      message_no_photo = create(:message, chat:, date: 1.hour.ago)
      messages = [message_w_photo, message_no_photo]

      results = YAML.parse(described_class.messages_to_yaml(messages)).children[0].to_ruby

      expect(results.last.key?(:attachment)).to be false
    end
  end
end
