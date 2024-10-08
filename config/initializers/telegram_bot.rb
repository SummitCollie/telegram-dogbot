# frozen_string_literal: true

temp_tg_client = Telegram::Bot::Client.new(
  Rails.application.credentials.telegram.bot.token,
  Rails.application.credentials.telegram.bot.username,
  async: false
)

# Set slash commands available from telegram UI
# https://core.telegram.org/bots/features#commands
temp_tg_client.set_my_commands(
  commands: [
    { command: 'summarize',
      description: 'Summarize messages since last summary (or as many as possible)' },
    { command: 'summarize_nicely', description: 'Summarize more positively' },
    { command: 'vibe_check', description: 'Run vibe analysis' },
    { command: 'translate', description: 'Translate text from your message or quoted message' },
    { command: 'chat_stats', description: 'Show stats about this chat' }
  ],
  language_code: 'en'
)

temp_tg_client = nil # rubocop:disable Lint/UselessAssignment
