# frozen_string_literal: true

FactoryBot.define do
  factory :chat do
    api_id { Faker::Number.between(from: 0, to: 2147483647) }
    api_type { Faker::Number.between(from: 1, to: 2) }
    title { Faker::Game.title }
  end
end
