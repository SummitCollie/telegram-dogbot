# frozen_string_literal: true

module LLM
  # Has the self-hosted model describe a sticker once, saved as a StickerDescription for reply prompts.
  # Best effort: skipped while the self-hosted model is unavailable or can't see images, and tried again
  # next time someone sends the sticker.
  class DescribeStickerJob < ApplicationJob
    MAX_TOKENS = 100

    def perform(file_unique_id, image_file_id, emoji)
      return if StickerDescription.exists?(file_unique_id:)

      model = LocalInferenceApi.available_model
      return unless model && LocalInferenceApi.vision?

      image = Base64.strict_encode64(TelegramTools.download_file(image_file_id))
      description = describe(model, image, emoji)
      StickerDescription.create!(file_unique_id:, description:) if description.present?
    rescue Telegram::Bot::Error => e
      TelegramTools.logger.warn("Couldn't describe sticker #{file_unique_id}: #{e.message}")
    rescue ActiveRecord::RecordNotUnique
      nil # someone sent it again while it was being described
    end

    private

    def describe(model, image, emoji)
      prompt = <<~PROMPT.strip
        Describe this Telegram sticker (emoji: #{emoji}) in one short sentence, for someone who can't see it:
        who or what is shown, what they're doing or feeling, and any text on it.
        Output only the description, without starting with "A sticker of".
      PROMPT

      LocalInferenceApi.run_chat_completion(
        model:,
        messages: [{ role: 'user', content: prompt, images: [image] }],
        model_params: { num_predict: MAX_TOKENS },
        request_params: { think: false }
      ).squish
    rescue Faraday::Error => e
      LocalInferenceApi.mark_unavailable!(e)
      nil
    end
  end
end
