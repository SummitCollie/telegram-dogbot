class TelegramWebhooksController < Telegram::Bot::UpdatesController
  # Auto typecast to types from telegram-bot-types gem
  include Telegram::Bot::UpdatesController::TypedUpdate

  ### Handle commands
  def summarize!(*); end

  def summarize_nicely!(*); end

  def stats!(*); end

  def action_missing(_action, *_args)
    return unless action_type == :command

    reply_with :message, text: 'Invalid command!'
  end

  ### Store incoming messages in DB - https://core.telegram.org/bots/api#message
  def message(message)
    logger.debug(message.to_yaml)

    store_message(message)

    # reply_with :message, text: message
  end

  def edited_message(message)
    store_edited_message(message)
    # reply_with :message, text: message
  end

  private

  def store_message(message)
    # return if message from bot

    # {"message_id"=>14,
    #   "from"=>{"id"=>273585821, "is_bot"=>false, "first_name"=>"Summit", "username"=>"summitbc", "language_code"=>"en"},
    #   "chat"=>{"id"=>-4276137123, "title"=>"Summit Test Chat", "type"=>"group", "all_members_are_administrators"=>true},
    #   "date"=>1721243973,
    #   "text"=>"some text"}

    # Time.at(message['date']).to_datetime
  end

  def store_edited_message(message)
    # {"message_id"=>14,
    #   "from"=>{"id"=>273585821, "is_bot"=>false, "first_name"=>"Summit", "username"=>"summitbc", "language_code"=>"en"},
    #   "chat"=>{"id"=>-4276137123, "title"=>"Summit Test Chat", "type"=>"group", "all_members_are_administrators"=>true},
    #   "date"=>1721243973,
    #   "edit_date"=>1721244550,
    #   "text"=>"edited message text!!!"}
  end
end
