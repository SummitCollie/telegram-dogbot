# frozen_string_literal: true

# What a sticker shows, as described by LLM::DescribeImageJob, so it's only described once. Keyed by Telegram's
# `file_unique_id`, which is the same for everyone who sends that sticker. Kept forever: stickers get reused long
# after the nightly purge deletes the messages they were sent in.
class StickerDescription < ApplicationRecord
  validates :file_unique_id, :description, presence: true
end
