# frozen_string_literal: true

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include AuthorizationHandler
  include MessageStorage

  # Auto typecast to types from telegram-bot-types gem
  include Telegram::Bot::UpdatesController::TypedUpdate

  rescue_from FuckyWuckies::AuthorizationError,
              FuckyWuckies::NotAGroupChatError,
              FuckyWuckies::ChatNotWhitelistedError,
              FuckyWuckies::MessageFilterError, with: :handle_error

  mattr_reader :stickers, default: {
    hmm: 'CAACAgEAAxkBAAN7Zpnjiy4fEBQDljYzOMMDE13t63cAAhYDAAJ1DsgJD2dJhv6G8sY1BA',
    nonono: 'CAACAgEAAxkBAAOJZpnq0Evpppl3W2tMIetOnKOVgj8AAgIDAAJ1DsgJCj6cMfALhQw1BA',
    spray_bottle: 'CAACAgEAAxkBAAORZpnuToKa-Hh0NZyFwC0GdJs4JeIAAmsKAALX8EUGAAHtDzfwk20gNQQ',
    gun: 'CAACAgEAAxkBAAOXZpn3TETXIjiJKnucdhdf3WOqj3EAAoEAA-QPqR9m982-evFo-zUE',
    heck: 'CAACAgEAAxkBAAO-ZpoHFLajSuHX6CqP6WIv7T097G0AArQAA-QPqR8Mpjf0MTIoSTUE'
  }

  ### Handle commands
  def summarize!(*)
    authorize_command!
  end

  def summarize_nicely!(*)
    authorize_command!
  end

  def stats!(*)
    authorize_command!
    # Messages from chat currently stored in DB
    # Total messages seen from chat (including deleted)
    # Message counts per user in a chat (only show top 5 users)
  end

  ### Handle unknown commands
  def action_missing(_action, *_args)
    return unless action_type == :command

    authorize_command!

    reply_with :message, text: 'Invalid command!'
  end

  ### Handle incoming message - https://core.telegram.org/bots/api#message
  def message(message)
    authorize_message_storage!(message)

    db_message = store_message(message)

    # reply_with :message, text: message
    reply_with :message, text: "Message ##{message.message_id} stored!" if db_message
  end

  ### Handle incoming edited message
  def edited_message(message)
    authorize_message_storage!(message)

    store_edited_message(message)
  end

  private

  def handle_error(error)
    logger.log(error.severity, error.message)
    bot.send_sticker(chat_id: chat.id, sticker: stickers[error.sticker]) if error.sticker
    respond_with :message, text: error.frontend_message if error.frontend_message
  end
end
