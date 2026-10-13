# frozen_string_literal: true

# Set slash commands available from telegram UI (after initialization, when app classes can be loaded)
Rails.application.config.after_initialize do
  TelegramTools.register_commands(
    Telegram::Bot::Client.new(
      Rails.application.credentials.telegram.bot.token,
      Rails.application.credentials.telegram.bot.username,
      async: false
    )
  )
end
