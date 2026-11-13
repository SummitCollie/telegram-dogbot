# frozen_string_literal: true

# A photo's (or image file's, shrunk) image data, for prompts to show self-hosted models with vision (see LLM::ReplyJob).
# Stored rather than downloaded for every reply; deleted along with its message by the nightly purge.
class MessageImage < ApplicationRecord
  belongs_to :message
end
