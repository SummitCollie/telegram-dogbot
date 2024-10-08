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
end
