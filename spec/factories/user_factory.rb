# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    api_id { Faker::Number.between(from: 0, to: 2147483647) }
    first_name { Faker::Name.first_name }
    username { Faker::Internet.username }
  end
end
