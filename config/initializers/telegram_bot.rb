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
      description: 'Show help for summarize features' },
    { command: 'summarize_url',
      description: 'Summarize content from a URL, optional custom style' },
    { command: 'summarize_chat',
      description: 'Summarize recent chat messages, optional custom style' },
    { command: 'translate',
      description: 'Translate text from your message or replied message' },
    { command: 'vibe_check',
      description: 'Advanced computer vibe analysis' },
    { command: 'chat_stats',
      description: 'Show stats about this chat' },
    { command: 'opt_out',
      description: '(send in bot DMs)'}
  ],
  language_code: 'en'
)

temp_tg_client = nil # rubocop:disable Lint/UselessAssignment
