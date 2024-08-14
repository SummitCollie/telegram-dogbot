# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    api_id { Faker::Number.between(from: 0, to: 2147483647) }
    chat_user
    date { Faker::Time.backward(days: 1) }
    text { Faker::Quote.famous_last_words }
  end
end
