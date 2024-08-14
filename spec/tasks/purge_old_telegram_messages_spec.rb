# frozen_string_literal: true

require 'rails_helper'
require 'rake'

Rails.application.load_tasks

RSpec.describe 'Rake Task: purge_old_telegram_messages' do
  # Rake prevents repeated re-runs of tasks by default smh
  # HOURS of debugging
  after { Rake::Task['purge_old_telegram_messages'].reenable }

  # rubocop:disable RSpec/LetSetup
  context 'when some messages in DB are > 2 days old' do
    let!(:chat1) { create(:chat) }
    let!(:chat2) { create(:chat) }
    let!(:old_messages1) do
      Array.new(25) do
        create(:message, chat: chat1,
                         date: Faker::Time.unique.between(from: 4.days.ago, to: 49.hours.ago))
      end
    end
    let!(:old_messages2) do
      Array.new(25) do
        create(:message, chat: chat2,
                         date: Faker::Time.unique.between(from: 4.days.ago, to: 49.hours.ago))
      end
    end
    let!(:new_messages1) do
      Array.new(25) do
        create(:message, chat: chat1,
                         date: Faker::Time.unique.between(from: 47.hours.ago, to: Time.current))
      end
    end
    let!(:new_messages2) do
      Array.new(25) do
        create(:message, chat: chat2,
                         date: Faker::Time.unique.between(from: 47.hours.ago, to: Time.current))
      end
    end

    it 'deletes messages > 2 days old' do
      Rake::Task['purge_old_telegram_messages'].invoke

      all_messages = Message.all

      expect(chat1.messages.count).to eq 25
      expect(chat2.messages.count).to eq 25
      expect(all_messages.count).to eq 50
      expect(all_messages).to match_array(new_messages1 + new_messages2)
    end

    it 'does not delete messages < 2 days old' do
      Rake::Task['purge_old_telegram_messages'].invoke

      all_messages = Message.all

      expect(all_messages).not_to include(old_messages1)
      expect(all_messages).not_to include(old_messages2)
    end
  end

  it 'nullifies `reply_to_message_id` on messages whose parents were deleted' do
    chat = create(:chat)
    parent_message = create(:message, chat:, date: 3.days.ago)
    reply_message = create(:message, chat:, reply_to_message_id: parent_message.id)

    Rake::Task['purge_old_telegram_messages'].invoke

    expect { parent_message.reload.id }.to raise_error(ActiveRecord::RecordNotFound)
    expect(reply_message.reload.reply_to_message).to be_nil
  end

  context 'when no messages in DB are > 2 days old' do
    let!(:chat1) { create(:chat) }
    let!(:chat2) { create(:chat) }
    let!(:new_messages1) do
      Array.new(25) do
        create(:message, chat: chat1,
                         date: Faker::Time.unique.between(from: 47.hours.ago, to: Time.current))
      end
    end
    let!(:new_messages2) do
      Array.new(25) do
        create(:message, chat: chat2,
                         date: Faker::Time.unique.between(from: 47.hours.ago, to: Time.current))
      end
    end

    it 'does nothing' do
      expect do
        Rake::Task['purge_old_telegram_messages'].invoke
      end.not_to change(Message, :count)
    end
  end
  # rubocop:enable RSpec/LetSetup
end
