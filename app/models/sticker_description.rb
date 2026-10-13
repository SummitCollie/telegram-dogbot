# frozen_string_literal: true

# What a sticker shows, written once by a vision model (see LLM::DescribeStickerJob) so prompts can
# describe stickers without sending their images. Keyed by Telegram's `file_unique_id`, which is the
# same for everyone who sends that sticker. Kept forever: stickers get reused long after the nightly
# purge deletes the messages they were sent in.
class StickerDescription < ApplicationRecord
  validates :file_unique_id, :description, presence: true
end
