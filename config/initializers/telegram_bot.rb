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
      description: 'Summarize content from a URL, optionally using a custom style' },
    { command: 'summarize_chat',
      description: 'Summarize messages since last summary (or as many as possible)' },
    { command: 'vibe_check', description: 'Run vibe analysis' },
    { command: 'translate', description: 'Translate text from your message or replied message' },
    { command: 'chat_stats', description: 'Show stats about this chat' }
  ],
  language_code: 'en'
)

temp_tg_client = nil # rubocop:disable Lint/UselessAssignment
