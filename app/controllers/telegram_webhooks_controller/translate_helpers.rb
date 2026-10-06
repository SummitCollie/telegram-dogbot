# frozen_string_literal: true

# rubocop:disable Layout/LineContinuationLeadingSpace
class TelegramWebhooksController
  module TranslateHelpers
    module_function

    # Returns [target_language, text_to_translate].
    # target_language is nil when the text was given after the command: it may or may not include a requested
    # target language (e.g. `/translate french hello`, `/translate hello into french`), so the LLM decides.
    def parse_translate_command
      # Text from (the message being replied to) by the user calling /translate (quote)
      reply_parent_text = payload.reply_to_message&.text&.strip.presence

      # Text from after the /translate command
      command_message_text = TelegramTools.strip_bot_command('translate', payload.text)

      # When the command replies to a message, any text after it is the target language (e.g. "into french")
      target_language, text_to_translate = if reply_parent_text
                                             [command_message_text.presence || 'english', reply_parent_text]
                                           else
                                             [nil, command_message_text]
                                           end

      if text_to_translate.blank?
        raise FuckyWuckies::TranslateJobFailure.new(
          severity: Logger::Severity::INFO,
          db_chat:,
          frontend_message: "💬 Translate\n" \
                            "• Reply to a message, or\n" \
                            "• Paste text after command:\n" \
                            "    /translate hola mi amigo\n\n" \
                            "⚙️ Choose target language\n" \
                            "    /translate polish hi there!\n" \
        ), 'Aborting translation, empty text_to_translate: ' \
           "chat api_id=#{db_chat.id} title=#{db_chat.title}"
      end

      [target_language, text_to_translate]
    end
  end
end
# rubocop:enable Layout/LineContinuationLeadingSpace
