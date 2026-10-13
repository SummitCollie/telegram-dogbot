# frozen_string_literal: true

module LLM
  # Has the self-hosted model describe a message's image (photo, sticker, or GIF/video thumbnail), for prompts
  # to show as e.g. `[photo: a shiba inu in sunglasses]`. Photos are also stored, for prompts to show models with
  # vision directly. Queued by ImageDescriptions.
  #
  # While the self-hosted model is unavailable or can't see images, the message is left pending: the next reply
  # that needs it queues it again.
  class DescribeImageJob < ApplicationJob
    MAX_TOKENS = 200
    MAX_DESCRIPTION_LENGTH = 600
    # Descriptions run one at a time, so a burst of images (e.g. an album) doesn't swamp the model
    DESCRIBE_MUTEX = Mutex.new

    PROMPTS = {
      photo: <<~PROMPT,
        Describe this image from a Telegram group chat in 1-2 short sentences, for someone who can't see it:
        what it shows, and anything notable, funny or weird about it. Get straight to it, like a caption,
        without "This is" or "The image shows". If it has text in it (e.g. a meme or screenshot), end with
        the text quoted word for word, like: Text: "..."
      PROMPT
      sticker: <<~PROMPT,
        Describe this Telegram sticker in one short sentence, for someone who can't see it:
        who or what is shown, what they're doing or feeling, and any text on it.
      PROMPT
      animation: <<~PROMPT,
        This is a still frame from a GIF sent in a Telegram group chat. Describe it in one short sentence,
        for someone who can't see it: who or what is shown, what's going on, and any text on it.
      PROMPT
      video: <<~PROMPT
        This is a still frame from a video sent in a Telegram group chat. Describe it in one short sentence,
        for someone who can't see it: who or what is shown, what's going on, and any text on it.
      PROMPT
    }.freeze

    def perform(message_id)
      message = Message.find_by(id: message_id)
      return unless message&.image_pending?
      return if describe_from_cache(message)

      describe(message, message.image&.data || download(message))
    rescue Telegram::Bot::Error => e
      TelegramTools.logger.warn("Couldn't download image of message id=#{message_id}: #{e.message}")
      message.update!(image_status: :failed)
    ensure
      ImageDescriptions.finished(message_id)
    end

    private

    def describe_from_cache(message)
      cached = StickerDescription.find_by(file_unique_id: message.sticker_file_unique_id) if message.sticker?
      message.update!(image_description: cached.description, image_status: :described) if cached
    end

    # Photos are kept for prompts. Other images are only needed for describing them.
    def download(message)
      data = TelegramTools.download_file(message.image_file_id)
      message.create_image!(data:) if message.photo?
      data
    end

    def describe(message, image)
      model = LocalInferenceApi.available_model
      return unless model && LocalInferenceApi.vision?

      description = DESCRIBE_MUTEX.synchronize { run_model(model, message, image) }
      save_description(message, description) unless description.nil?
    end

    # nil if the self-hosted model failed
    def run_model(model, message, image)
      prompt = PROMPTS.fetch(message.attachment_type.to_sym, PROMPTS[:photo])
      context = if message.sticker? then "Its emoji: #{message.text}"
                elsif message.text.present? then "It was sent with this caption, for context: #{message.text}"
                end

      LocalInferenceApi.run_chat_completion(
        model:,
        messages: [{ role: 'user', content: [prompt, context, 'Output only the description.'].compact.join("\n"),
                     images: [Base64.strict_encode64(image)] }],
        model_params: { num_predict: MAX_TOKENS },
        request_params: { think: false }
      ).squish.truncate(MAX_DESCRIPTION_LENGTH)
    rescue Faraday::Error => e
      LocalInferenceApi.mark_unavailable!(e)
      nil
    end

    def save_description(message, description)
      if description.blank?
        TelegramTools.logger.warn("Blank description of image of message id=#{message.id}")
        return message.update!(image_status: :failed)
      end

      message.update!(image_description: description, image_status: :described)
      return unless message.sticker? && message.sticker_file_unique_id

      StickerDescription.create_or_find_by!(file_unique_id: message.sticker_file_unique_id) do |sticker|
        sticker.description = description
      end
    end
  end
end
