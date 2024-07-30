# frozen_string_literal: true

FactoryBot.define do
  factory :chat_user do
    chat
    user
    num_chatuser_messages { Faker::Number.between(from: 1, to: 1000) }
  end
end
