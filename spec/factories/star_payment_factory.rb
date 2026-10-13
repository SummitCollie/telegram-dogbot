# frozen_string_literal: true

FactoryBot.define do
  factory :star_payment do
    user
    sequence(:telegram_payment_charge_id) { |n| "charge_#{n}" }
    subscription_charge_id { telegram_payment_charge_id }
    total_amount { 250 }
    invoice_payload { "#{Premium::PAYLOAD_PREFIX}:#{user.api_id}" }
    expires_at { 30.days.from_now }
    is_recurring { true }
    is_first_recurring { true }
  end
end
