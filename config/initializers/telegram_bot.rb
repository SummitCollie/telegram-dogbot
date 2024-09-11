# frozen_string_literal: true

MIN_MESSAGES_BETWEEN_SUMMARIES = 100

client = Telegram::Bot::Client.new(
  Rails.application.credentials.telegram.bot.token,
  Rails.application.credentials.telegram.bot.username,
  async: false
)

# Set slash commands available from telegram UI
# https://core.telegram.org/bots/features#commands
client.set_my_commands(
  commands: [
    { command: 'summarize',
      description: 'Summarize messages since last summary (or as many as possible)' },
    { command: 'summarize_nicely', description: 'Summarize more positively' },
    { command: 'vibe_check', description: 'Run vibe analysis' }
    # { command: 'stats', description: 'Show group chat stats' }
  ],
  language_code: 'en'
)
