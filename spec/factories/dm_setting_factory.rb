# frozen_string_literal: true

FactoryBot.define do
  factory :dm_setting do
    user
    consented_at { 1.day.ago }
    consented_terms_version { Premium::TERMS_VERSION }

    trait :not_consented do
      consented_at { nil }
      consented_terms_version { nil }
    end
  end
end
