# frozen_string_literal: true

# TODO: remove this when supported upstream
# telegram-bot-types 0.7.0 predates video stickers and the Bot API renaming `thumb` to `thumbnail`,
# and typed updates drop fields their types don't declare
module HackyWackies
  module TelegramStickerType
    Types = Telegram::Bot::Types

    Types::Sticker.attribute :is_video, Types::Boolean unless Types::Sticker.attribute_names.include?(:is_video)
    Types::Sticker.attribute :thumbnail, Types::PhotoSize unless Types::Sticker.attribute_names.include?(:thumbnail)
  end
end
