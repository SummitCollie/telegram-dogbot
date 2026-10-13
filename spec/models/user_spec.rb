# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe '#set_bot_user_attrs' do
    it 'sets correct attributes on User created for this bot when saving it' do
      bot_user = create(:user, is_this_bot: true)

      expect(bot_user).to have_attributes(
        api_id: -1,
        is_bot: true,
        username: Rails.application.credentials.telegram.bot.username,
        first_name: Rails.application.credentials.telegram.bot.first_name
      )
    end

    it 'does not set attributes for this bot on other created users' do
      human_user = create(:user, is_this_bot: false)

      expect(human_user).not_to have_attributes(
        api_id: -1,
        is_bot: true,
        username: Rails.application.credentials.telegram.bot.username,
        first_name: Rails.application.credentials.telegram.bot.first_name
      )
    end
  end

  describe 'premium' do
    let(:user) { create(:user) }

    it 'is premium while a payment covers now' do
      expect(user).not_to be_premium

      create(:star_payment, user:, expires_at: 1.day.ago)
      expect(user).not_to be_premium

      payment = create(:star_payment, user:, expires_at: 3.days.from_now)
      expect(user).to be_premium
      expect(user.premium_until).to be_within(1.second).of(payment.expires_at)
      expect(user.current_payment).to eq payment
    end

    it 'ignores refunded payments' do
      create(:star_payment, user:, refunded_at: Time.current)

      expect(user).not_to be_premium
      expect(user.premium_until).to be_nil
    end

    it 'is always premium for the owner' do
      owner = create(:user, username: Rails.application.credentials.telegram.bot.owner_username)

      expect(owner).to be_owner
      expect(owner).to be_premium
    end
  end

  describe '#forget_dms!' do
    let(:user) { create(:user) }
    let(:dm_chat) { create(:chat, api_id: user.api_id, api_type: :private_room) }

    it 'deletes all messages of their DMs with the bot, and nothing else' do
      own = create(:message, chat_user: create(:chat_user, chat: dm_chat, user:))
      bot = create(:user, is_this_bot: true)
      bot_reply = create(:message, chat_user: create(:chat_user, chat: dm_chat, user: bot), reply_to_message: own)
      group_message = create(:message, chat_user: create(:chat_user, user:))

      expect(user.forget_dms!).to eq 2
      expect(Message.where(id: [own.id, bot_reply.id])).to be_empty
      expect(group_message.reload).to be_present
    end

    it 'does nothing without a DM chat' do
      expect(user.forget_dms!).to eq 0
    end
  end
end
