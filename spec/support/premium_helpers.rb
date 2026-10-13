# frozen_string_literal: true

module PremiumHelpers
  def enable_premium(price_stars: 250, **config)
    allow(Premium).to receive(:config).and_return(OpenStruct.new(price_stars:, **config))
  end

  # A premium user with their DM chat (private chats' IDs are their users' IDs)
  def create_premium_user(**attrs)
    user = create(:user, **attrs)
    create(:dm_setting, user:)
    create(:star_payment, user:)
    user
  end

  def private_chat_for(user)
    Chat.find_or_create_by!(api_id: user.api_id, api_type: :private_room)
  end
end

RSpec.configure { |config| config.include PremiumHelpers }
