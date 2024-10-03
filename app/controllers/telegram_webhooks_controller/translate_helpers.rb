# frozen_string_literal: true

class TelegramWebhooksController
  module TranslateHelpers
    extend self

    def detect_target_language(first_input_word)
      candidate = first_input_word&.downcase
      supported_languages = Rails.application.credentials.openai.translate_languages&.map(&:downcase)

      supported_languages.include?(candidate) ? candidate : nil
    end

    def determine_text_to_translate(target_language, first_input_word)
      # Text from (the message being replied to) by the user calling /translate (quote)
      reply_parent_text = payload.reply_to_message&.text&.strip

      # Text from after the /translate command (ignored if reply_parent_text exists)
      command_message_text = if target_language
                               payload.text.gsub(%r{^/translate(\S?)+ #{Regexp.escape(first_input_word)}}, '').strip
                             else
                               payload.text.gsub(%r{^/translate(\S?)+}, '').strip
                             end

      text_to_translate = reply_parent_text || command_message_text

      if text_to_translate.blank?
        raise FuckyWuckies::TranslateJobFailure.new(
          severity: Logger::Severity::INFO,
          db_chat:,
          frontend_message: "💬 Translate\n" \
                            "• Reply to a message, or\n" \
                            "• Paste text after command:\n" \
                            "    /translate hola mi amigo\n\n" \
                            "⚙️ Choose target language\n" \
                            "    /translate polish hi there!\n\n" \
                            "❔ Supported languages\n" \
                            "#{Rails.application.credentials.openai.translate_languages.join(', ')}"
        ), 'Aborting translation, empty text_to_translate: ' \
           "chat api_id=#{db_chat.id} title=#{db_chat.title}"
      end

      text_to_translate
    end
  end
end
