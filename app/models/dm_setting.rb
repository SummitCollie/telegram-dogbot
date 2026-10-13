# frozen_string_literal: true

# A user's settings for DMs with the bot: consent, the bot's persona, and how long their DMs are remembered.
# Edited in the Mini App (see MiniAppController).
class DmSetting < ApplicationRecord
  # Days to keep DM messages for. The minimum matches group chats (see nightly_data_purge).
  RETENTION_DAYS = [2, 7, 30].freeze
  DEFAULT_RETENTION_DAYS = RETENTION_DAYS.first

  # `creativity` (0-4) => LLM temperature
  TEMPERATURES = [0.6, 0.8, 1.0, 1.15, 1.3].freeze

  MAX_LENGTHS = { bot_name: 32, persona: 2000, user_name: 32, user_bio: 500 }.freeze

  PRESETS = YAML.load_file(Rails.root.join('data/dm_presets.yml')).map(&:deep_symbolize_keys).freeze
  DEFAULT_PRESET = PRESETS.first

  # Fields users can change in the Mini App
  EDITABLE_ATTRIBUTES = %i[bot_name persona user_name user_bio reply_length creativity double_texting
                           retention_days].freeze

  enum :reply_length, { short: 0, normal: 1, long: 2 }, prefix: true

  belongs_to :user

  validates :retention_days, inclusion: { in: RETENTION_DAYS }
  validates :creativity, inclusion: { in: 0...TEMPERATURES.size }
  validates :double_texting, inclusion: { in: [true, false] }
  MAX_LENGTHS.each { |attr, max| validates attr, length: { maximum: max } }

  def consented?
    consented_at.present? && consented_terms_version.to_i >= Premium::TERMS_VERSION
  end

  def consent!
    update!(consented_at: Time.current, consented_terms_version: Premium::TERMS_VERSION)
  end

  def temperature
    TEMPERATURES[creativity]
  end

  def effective_bot_name
    bot_name.presence || DEFAULT_PRESET[:bot_name]
  end

  def effective_persona
    persona.presence || DEFAULT_PRESET[:persona]
  end

  def effective_user_name
    user_name.presence || user.first_name.presence || 'them'
  end

  # Back to the default persona/style, keeping consent and retention
  def reset_persona!
    update!(bot_name: nil, persona: nil, user_name: nil, user_bio: nil,
            **self.class.column_defaults.slice('reply_length', 'creativity', 'double_texting'))
  end
end
