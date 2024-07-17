class TelegramWebhooksController < Telegram::Bot::UpdatesController

  ### Handle commands
  def summarize!(*)
    # respond_with :message, text: t('.content')
  end

  def summarize_nicely!(*)
    # respond_with :message, text: t('.content')
  end

  def stats!(*args)
    # TODO
  end

  ### Store incoming messages in DB - https://core.telegram.org/bots/api#message
  def message(message)
    # New message:
    #{"update_id"=>461170622,
    #  "message"=>
    #  {"message_id"=>3,
    #    "from"=>{"id"=>273585821, "is_bot"=>false, "first_name"=>"Summit", "username"=>"summitbc", "language_code"=>"en"},
    #    "chat"=>{"id"=>273585821, "first_name"=>"Summit", "username"=>"summitbc", "type"=>"private"},
    #    "date"=>1721189520,
    #    "text"=>"/start",
    #    "entities"=>[{"offset"=>0, "length"=>6, "type"=>"bot_command"}]}}

    # store_message(message['text'])
    # Time.at(message['date']).to_datetime
    puts message
  end

  def edited_message
    # Edited message:
    #{"update_id"=>461170623,
    #  "edited_message"=>
    #    {"message_id"=>3,
    #    "from"=>{"id"=>273585821, "is_bot"=>false, "first_name"=>"Summit", "username"=>"summitbc", "language_code"=>"en"},
    #    "chat"=>{"id"=>273585821, "first_name"=>"Summit", "username"=>"summitbc", "type"=>"private"},
    #    "date"=>1721189520,
    #    "edit_date"=>1721189564,
    #    "text"=>"/start test",
    #    "entities"=>[{"offset"=>0, "length"=>6, "type"=>"bot_command"}]}}
  end

  def action_missing(action, *_args)
    if action_type == :command
      reply_with :message, text: "Invalid command!"
    end
  end
end
