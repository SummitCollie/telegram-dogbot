# frozen_string_literal: true

class TelegramWebhooksController
  # Premium DMs (see Premium)
  module PremiumHelpers
    UNREADABLE_MESSAGE = '📎 I can only read text (and captions) for now.'

    private

    def private_chat?
      chat&.type == 'private'
    end

    # The update as received, with fields telegram-bot-types (last updated in 2022) doesn't know about,
    # like subscription details of payments
    def raw_update
      @raw_update ||= @unparsed_update ? JSON.parse(@unparsed_update.to_json) : {}
    end

    def handle_direct_message(message)
      return handle_payment_message if payment_message?
      return authorize_message_storage!(message) unless Premium.enabled? # "this bot is for group chats"
      return if from.blank? || from.is_bot

      reply_to_direct_message(message, create_or_update_user)
    end

    def reply_to_direct_message(message, db_user)
      return send_onboarding unless db_user.dm_setting&.consented?
      return send_paywall(db_user) unless db_user.premium?
      return send_html_message(UNREADABLE_MESSAGE) if TelegramTools.extract_message_text(message).blank?

      LLM::DirectReplyJob.enqueue(store_message(message))
    end

    def handle_direct_edit(message)
      db_user = User.find_by(api_id: from&.id)
      return unless db_user&.premium? && db_user.dm_setting&.consented?
      return if TelegramTools.extract_message_text(message).blank?

      store_edited_message(message)
    end

    # What /start, /subscription etc. show, depending on where the user's at
    def send_premium_status
      db_user = create_or_update_user
      Premium.setup_private_chat(chat.id)

      if !db_user.dm_setting&.consented?
        send_onboarding
      elsif db_user.premium?
        status = Premium.text(:subscription, owner: db_user.owner?, payment: db_user.current_payment,
                                             paid_until: format_paid_until(db_user))
        send_html_message(status, reply_markup: Premium.settings_keyboard)
      else
        send_paywall(db_user)
      end
    end

    def send_onboarding
      send_html_message(Premium.text(:onboarding), reply_markup: Premium.consent_keyboard)
    end

    def send_paywall(db_user)
      send_html_message(Premium.text(:paywall), reply_markup: Premium.paywall_keyboard(db_user))
    end

    def send_welcome(db_user)
      welcome = Premium.text(:welcome, paid_until: format_paid_until(db_user))
      send_html_message(welcome, reply_markup: Premium.settings_keyboard)
    end

    def format_paid_until(db_user)
      paid_until = db_user.premium_until
      paid_until ? Premium.format_date(paid_until) : 'forever'
    end

    def send_html_message(text, reply_markup: nil)
      Telegram.bot.send_message(chat_id: chat.id, text:, parse_mode: 'HTML', reply_markup:,
                                link_preview_options: { is_disabled: true })
    end

    def premium_consent_pressed
      db_user = create_or_update_user
      db_user.dm_setting!.consent!
      answer_callback_query('Thanks!')
      remove_buttons(payload.message)
      db_user.premium? ? send_welcome(db_user) : send_paywall(db_user)
    end

    def premium_forget_pressed
      db_user = User.find_by(api_id: from.id)
      count = db_user&.forget_dms! || 0
      answer_callback_query('Forgotten')
      Telegram.bot.edit_message_text(chat_id: chat.id, message_id: payload.message.message_id, parse_mode: 'HTML',
                                     text: "🗑 <b>Done.</b> I forgot our DM history (#{count} messages).")
    end

    def remove_buttons(message)
      Telegram.bot.edit_message_reply_markup(chat_id: chat.id, message_id: message.message_id,
                                             reply_markup: { inline_keyboard: [] })
    rescue Telegram::Bot::Error
      nil
    end

    def owner_message?
      from&.username.present? && from.username == Rails.application.credentials.telegram.bot.owner_username
    end
  end
end
