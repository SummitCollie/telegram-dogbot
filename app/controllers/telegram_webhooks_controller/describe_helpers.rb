# frozen_string_literal: true

class TelegramWebhooksController
  # Secret `/describe` command, for checking image descriptions (see LLM::DescribeImageJob)
  module DescribeHelpers
    module_function

    # Status or description of the image in the message `/describe` replies to
    def image_description_text
      target = payload.reply_to_message
      return 'Reply to a photo, sticker, GIF or video with /describe to see its description' unless target
      return "Images aren't described in this chat" unless db_chat.vision_enabled?

      message = db_chat.messages.find_by(api_id: target.message_id)
      return "I don't have that message (anymore)" unless message

      describe_status(message)
    end

    def describe_status(message)
      case message.image_status
      when 'described' then "[#{message.attachment_label}]"
      when 'pending' then retry_description(message, 'Not described yet')
      when 'failed' then retry_description(message, "Couldn't describe it")
      else 'Nothing to describe in that message'
      end
    end

    # Queues describing it again (if not already), when it can be
    def retry_description(message, status)
      unless LocalInferenceApi.available_model.present? && LocalInferenceApi.vision?
        return "#{status}, and the model that can see images isn't available right now"
      end

      message.update!(image_status: :pending)
      ImageDescriptions.request([message])
      "#{status}, looking at it now: try again in a bit"
    end

    # Not stored like other bot messages, so it doesn't end up in chat history for prompts
    def send_describe_reply(text)
      Telegram.bot.send_message(chat_id: chat.id, text:, disable_notification: true,
                                reply_parameters: { message_id: payload.message_id, allow_sending_without_reply: true })
    end
  end
end
