# frozen_string_literal: true

class TelegramWebhooksController
  module AuthorizationHandler
    extend self

    def authorize_command!
      if from_bot?
        raise FuckyWuckies::AuthorizationError.new(
          frontend_message: 'begone bot',
          sticker: :gun
        ), "Another bot tried to run a command: user api_id=#{from.id} username=@#{from.username}"
      end

      unless group_chat?
        raise FuckyWuckies::AuthorizationError.new(
          severity: Logger::INFO,
          frontend_message: 'the commands only work in group chats!!!1',
          sticker: :spray_bottle
        ), 'Command sent from non-group chat: ' \
           "chat api_id=#{chat.id} username=@#{chat.username}"
      end

      unless chat_in_whitelist?
        raise FuckyWuckies::ChatNotWhitelistedError.new(
          severity: Logger::INFO,
          frontend_message: "This chat isn't whitelisted (AI costs money)!\n" \
                            "Contact Summit and maybe he'll allow it.",
          sticker: :hmm
        ), "Chat not in whitelist: chat api_id=#{chat.id} title=#{chat.title}"
      end
    end

    def authorize_message_storage!(message)
      if from_bot?
        raise FuckyWuckies::MessageFilterError.new, "Not saving message from bot: message api_id=#{message.message_id}"
      end

      if empty_text?(message)
        raise FuckyWuckies::MessageFilterError.new, 'Not saving message with empty text: ' \
                                                    "message api_id=#{message.message_id}"
      end

      unless group_chat?
        raise FuckyWuckies::AuthorizationError.new(
          severity: Logger::INFO,
          frontend_message: 'This bot is for group chats. ' \
                            'It has no functionality in DMs or channels.' \
                            "\n\nbut hewwo :3 *nuzzles u*",
          sticker: :heck
        ), 'Not saving message from non-group chat: ' \
           "chat api_id=#{chat.id} username=@#{chat.username}"
      end

      unless chat_in_whitelist?
        raise FuckyWuckies::ChatNotWhitelistedError.new(
          severity: Logger.INFO
        ), 'Not saving message from un-whitelisted chat: ' \
           "chat api_id=#{chat.id} username=@#{chat.username} title=#{chat.title}"
      end
    end

    private

    def from_bot?
      from.is_bot
    end

    def empty_text?(message)
      message.text.nil?
    end

    def group_chat?
      chat.type == 'group' || chat.type == 'supergroup'
    end

    def chat_in_whitelist?
      Rails.application.credentials.chat_id_whitelist&.include?(chat.id)
    end
  end
end
