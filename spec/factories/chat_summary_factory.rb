# frozen_string_literal: true

FactoryBot.define do
  factory :chat_summary do
    chat
    status { :running }
    summary_type { 0 }
    text { Faker::Lorem.paragraphs(number: 4).join(' ') }
  end
end
