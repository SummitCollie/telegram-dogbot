# frozen_string_literal: true

# Set slash commands available from telegram UI
# https://core.telegram.org/bots/features#commands
Telegram.bot.set_my_commands commands: [
  { command: 'summarize',
    description: 'Summarize messages since last summary (or as many as possible)' },
  { command: 'summarize_nicely', description: 'Summarize more positively' },
  { command: 'vibe_check', description: 'Run vibe analysis' }
]

# Register endpoint for telegram webhook events in production
Rake::Task['telegram:bot:set_webhook'].invoke if Rails.env.production?
