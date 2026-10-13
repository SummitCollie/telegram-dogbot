# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DmSetting do
  let(:setting) { create(:dm_setting) }

  describe 'validations' do
    it 'only allows the offered retention periods' do
      expect(setting.update(retention_days: 7)).to be true
      expect(setting.update(retention_days: 1)).to be false
      expect(setting.errors[:retention_days]).to be_present
    end

    it 'limits creativity to the available temperatures' do
      expect(setting.update(creativity: described_class::TEMPERATURES.size - 1)).to be true
      expect(setting.update(creativity: described_class::TEMPERATURES.size)).to be false
    end

    it 'limits text lengths' do
      expect(setting.update(persona: 'a' * described_class::MAX_LENGTHS[:persona])).to be true
      expect(setting.update(persona: 'a' * (described_class::MAX_LENGTHS[:persona] + 1))).to be false
    end
  end

  describe '#consented?' do
    it 'is false until consent!' do
      setting = create(:dm_setting, :not_consented)
      expect(setting).not_to be_consented

      setting.consent!

      expect(setting).to be_consented
      expect(setting.consented_terms_version).to eq Premium::TERMS_VERSION
    end

    it 'is false when the user agreed to older terms' do
      setting.update!(consented_terms_version: Premium::TERMS_VERSION - 1)

      expect(setting).not_to be_consented
    end
  end

  describe 'effective persona' do
    it 'uses the default preset when blank' do
      expect(setting.effective_bot_name).to eq described_class::DEFAULT_PRESET[:bot_name]
      expect(setting.effective_persona).to eq described_class::DEFAULT_PRESET[:persona]
    end

    it "uses the user's first name when they didn't say what to call them" do
      expect(setting.effective_user_name).to eq setting.user.first_name

      setting.update!(user_name: 'Pup')
      expect(setting.effective_user_name).to eq 'Pup'
    end
  end

  describe '#reset_persona!' do
    it 'resets persona & style, keeping consent and retention' do
      setting.update!(bot_name: 'Rex', persona: 'grumpy', user_name: 'Pup', user_bio: 'likes bones',
                      reply_length: :long, creativity: 4, double_texting: false, retention_days: 30)

      setting.reset_persona!

      expect(setting.reload).to have_attributes(
        bot_name: nil, persona: nil, user_name: nil, user_bio: nil, reply_length: 'normal', creativity: 2,
        double_texting: true, retention_days: 30
      )
      expect(setting).to be_consented
    end
  end
end
