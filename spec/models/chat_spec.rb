# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat do
  describe '#messages_since_last_summary' do
    let(:chat) { create(:chat) }
    let(:human1) { create(:user) }
    let(:human2) { create(:user) }
    let(:bot) { create(:user, is_this_bot: true) }

    before do
      # create an old ChatSummary older than all the messages so results contain everything since then
      create(:chat_summary, chat:, status: :complete,
                            summary_type: 'vibe_check', created_at: 2.days.ago)

      [human1, human2, bot].each do |u|
        cu = create(:chat_user, chat:, user: u)
        50.times { create(:message, chat_user: cu) } # rubocop:disable FactoryBot/CreateList
      end
    end

    it 'gets all messages sent by humans, not ones from this bot' do
      human1_cu = chat.chat_users.find_by(user: human1)
      human2_cu = chat.chat_users.find_by(user: human2)

      results = chat.messages_since_last_summary(:vibe_check)

      expect(results.size).to eq 100
      expect(results).to match_array(human1_cu.messages + human2_cu.messages)
    end

    it 'excludes messages sent by this bot' do
      bot_cu = chat.chat_users.find_by(user: bot)

      results = chat.messages_since_last_summary(:vibe_check)

      expect(results).not_to include(*bot_cu.messages)
    end
  end
end
