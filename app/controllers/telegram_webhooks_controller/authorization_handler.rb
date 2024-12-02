# frozen_string_literal: true

# rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
class TelegramWebhooksController
  module AuthorizationHandler
    extend self

    def authorize_command!
      if db_chat.blank?
        raise FuckyWuckies::MessageFilterError.new(
          severity: Logger::Severity::ERROR
        ), 'Refusing command (Chat not initialized?? weird error alert!!!) - ' \
           "chat api_id=#{chat&.id || '?'} title=#{chat&.title || '?'}"
      end

      if from.blank? || chat.blank?
        # All the updates we care about will have `chat` and `from` attrs.
        # If not (polls etc), discard with a warning so I remember to set up `allowed_updates`:
        # https://core.telegram.org/bots/api#setwebhook
        raise FuckyWuckies::MessageFilterError.new(
          severity: Logger::Severity::WARN
        ), 'Ignoring update (missing params I want): ' \
           "chat api_id=#{db_chat.id} title=#{db_chat.title}"
      end

      if from_bot?
        # Found out after writing this that bots can't see each other's messages anyway lol.
        # Oh well, I'll leave this here in case that changes in the future.
        raise FuckyWuckies::AuthorizationError.new(
          frontend_message: 'begone bot',
          sticker: :gun
        ), "Another bot tried to run a command: user api_id=#{from.id} username=@#{from.username}"
      end

      unless group_chat?
        raise FuckyWuckies::AuthorizationError.new(
          severity: Logger::Severity::INFO,
          frontend_message: 'the commands only work in group chats!!!1',
          sticker: :spray_bottle
        ), 'Command sent from non-group chat: ' \
           "chat api_id=#{chat.id} username=@#{chat.username}"
      end

      if whitelist_enabled? && !chat_in_whitelist?
        raise FuckyWuckies::ChatNotWhitelistedError.new(
          severity: Logger::Severity::INFO,
          frontend_message: "This chat isn't whitelisted; contact this bot's owner.",
          sticker: :bonk
        ), "Chat not in whitelist: chat api_id=#{chat.id} title=#{chat.title}"
      end

      # Ignore commands from users who've opted out
      db_user = User.find_by(api_id: from.id)
      if db_user&.opt_out
        raise FuckyWuckies::AuthorizationError.new(
          severity: Logger::Severity::INFO,
        ), "Ignoring command from opted-out user: api_id=#{from.id} username=@#{from.username}"
      end
    end

    def authorize_message_storage!(message)
      ### Actually I do want to save messages from bots now.
      # if from_bot?
      #   raise FuckyWuckies::MessageFilterError.new, "Not saving message from bot: message api_id=#{message.message_id}"
      # end

      if TelegramTools.extract_message_text(message).blank?
        raise FuckyWuckies::MessageFilterError.new, 'Not saving message with empty text: ' \
                                                    "message api_id=#{message.try(:message_id) || '?'}"
      end

      unless group_chat?
        raise FuckyWuckies::AuthorizationError.new(
          severity: Logger::Severity::INFO,
          frontend_message: 'This bot is for group chats. ' \
                            'It has no functionality in DMs or channels.' \
                            "\n\nbut hewwo :3 *nuzzles u*",
          sticker: :heck
        ), 'Not saving message from non-group chat: ' \
           "chat api_id=#{chat.id} username=@#{chat.username}"
      end

      if whitelist_enabled? && !chat_in_whitelist?
        raise FuckyWuckies::ChatNotWhitelistedError.new(
          severity: Logger::Severity::INFO
        ), 'Not saving message from non-whitelisted chat: ' \
           "chat api_id=#{chat.id} username=@#{chat.username} title=#{chat.title}"
      end
    end

    private

    def from_bot?
      from.is_bot
    end

    def group_chat?
      chat.type == 'group' || chat.type == 'supergroup'
    end

    def whitelist_enabled?
      Rails.application.credentials.whitelist_enabled == true
    end

    def chat_in_whitelist?
      Rails.application.credentials.chat_id_whitelist&.include?(chat.id)
    end
  end
end
# rubocop:enable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
