# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat do
  describe '#messages_to_summarize' do
    let(:chat) { create(:chat) }
    let(:human) { create(:user) }
    let(:bot) { create(:user, is_this_bot: true) }
    let(:other_bot) { create(:user, is_bot: true) }

    before do
      allow_any_instance_of(described_class).to receive(:min_messages_between_summaries).and_return(2)

      # create an old ChatSummary older than all the messages so results contain everything since then
      create(:chat_summary, chat:, status: :complete,
                            summary_type: :vibe_check, created_at: 2.days.ago)

      [human, bot, other_bot].each do |u|
        cu = create(:chat_user, chat:, user: u)
        10.times { create(:message, chat_user: cu) } # rubocop:disable FactoryBot/CreateList
      end
    end

    it 'includes all messages sent by humans, this bot, and other bots' do
      human_cu = chat.chat_users.find_by(user: human)
      bot_cu = chat.chat_users.find_by(user: bot)
      other_bot_cu = chat.chat_users.find_by(user: other_bot)

      results = chat.messages_to_summarize(:vibe_check)

      expect(results.size).to eq 30
      expect(results).to match_array(human_cu.messages + bot_cu.messages + other_bot_cu.messages)
    end

    context 'when no prior ChatSummary with same summary_type exists' do
      it 'just grabs the last 200 messages'
    end

    # based on number of messages since last ChatSummary (see Chat#min_messages_between_summaries)
    context 'when last ChatSummary was too recent to ignore older messages' do
      it 'defaults to the last 200 messages'
    end

    context 'when last ChatSummary is old enough that we can ignore older messages' do
      it 'excludes messages sent before the last ChatSummary of same type' do
        human_cu = chat.chat_users.find_by(user: human)
        older_message = create(:message, chat_user: human_cu, date: 3.days.ago)

        10.times do |n|
          # random times assigned by message_factory make this test flaky otherwise
          create(:message, chat_user: human_cu, text: 'extra msg for summary', date: n.minutes.ago)
        end

        results = chat.messages_to_summarize(:vibe_check)

        expect(results).not_to include older_message
      end

      it 'includes messages sent before a more recent ChatSummary of a different type' do
        create(:chat_summary, chat:, status: :complete,
                              summary_type: :custom, style: 'as a poem written by a dog',
                              created_at: 1.minute.ago)

        results = chat.messages_to_summarize(:vibe_check)

        expect(results.size).to eq 30
      end
    end
  end
end
