# frozen_string_literal: true

# Paid DMs with the bot: a monthly Telegram Stars subscription (`premium` in rails credentials).
# https://core.telegram.org/bots/payments-stars
#
# Users first confirm they're 18+ and agree to the terms & privacy notice (DmSetting#consent!),
# then subscribe through an invoice link. Each payment (incl. automatic renewals) arrives as a
# `successful_payment` message, recorded as a StarPayment granting access until its `expires_at`.
class Premium
  # Bump when the terms/privacy notice change materially: users must agree again before DMing
  TERMS_VERSION = 1

  # The only subscription period Telegram allows
  SUBSCRIPTION_PERIOD = 30.days

  PAYLOAD_PREFIX = 'premium-v1'
  CURRENCY = 'XTR'
  CONSENT_DATA = 'premium_consent'
  FORGET_DATA = 'premium_forget'

  class << self
    def config
      Rails.application.credentials.premium
    end

    def enabled?
      config.present? && price.positive?
    end

    def price
      config&.price_stars.to_i
    end

    def bot_name
      Rails.application.credentials.telegram.bot.first_name
    end

    def support_contact
      config&.support_contact.presence || "@#{Rails.application.credentials.telegram.bot.owner_username}"
    end

    # Where the settings Mini App is served (see MiniAppController), or nil if there's no public HTTPS host
    def mini_app_url
      credentials = Rails.application.credentials
      host = Rails.env.production? ? credentials.host_url : credentials.ngrok_url
      "https://#{host}/mini_app" if host.present?
    end

    ### Payments

    def invoice_payload(user)
      "#{PAYLOAD_PREFIX}:#{user.api_id}"
    end

    # Link to pay for a subscription, for a `url` button or the Mini App's `openInvoice`
    def invoice_link(user)
      response = Telegram.bot.async(false) do
        Telegram.bot.create_invoice_link(
          title: "#{bot_name} Premium",
          description: config&.description.presence || "Unlimited DMs with #{bot_name}, " \
                                                       'with a personality you choose. Renews every 30 days.',
          payload: invoice_payload(user),
          currency: CURRENCY,
          prices: [{ label: '30 days', amount: price }],
          subscription_period: SUBSCRIPTION_PERIOD.to_i
        )
      end
      response['result']
    end

    # Reason to refuse a payment (shown to the user by Telegram), or nil if it's fine
    def checkout_error(user, payload:, currency:, total_amount:)
      return "#{bot_name} isn't taking payments right now, sorry!" unless enabled?
      unless current_invoice?(user, payload:, currency:, total_amount:)
        return 'This invoice is outdated, please use /subscribe again'
      end
      return 'Please agree to the terms first: send /start' unless user.dm_setting&.consented?

      paid_until = user.premium_until
      "You're already subscribed until #{format_date(paid_until)}" if paid_until&.future?
    end

    # https://core.telegram.org/bots/api#successfulpayment (a Hash: newer fields aren't in telegram-bot-types)
    def record_payment!(user, successful_payment)
      charge_id = successful_payment['telegram_payment_charge_id']
      existing = StarPayment.find_by(telegram_payment_charge_id: charge_id)
      return existing if existing # Telegram may deliver an update more than once

      expiration = successful_payment['subscription_expiration_date']
      first = successful_payment['is_first_recurring'] == true

      user.star_payments.create!(
        telegram_payment_charge_id: charge_id,
        subscription_charge_id: first ? charge_id : user.star_payments.order(:created_at).last&.subscription_charge_id,
        total_amount: successful_payment['total_amount'],
        invoice_payload: successful_payment['invoice_payload'],
        expires_at: expiration ? Time.zone.at(expiration) : SUBSCRIPTION_PERIOD.from_now,
        is_recurring: successful_payment['is_recurring'] == true,
        is_first_recurring: first
      )
    end

    # Refunds a payment through Telegram, ending the access it paid for
    def refund!(payment)
      Telegram.bot.async(false) do
        Telegram.bot.refund_star_payment(user_id: payment.user.api_id,
                                         telegram_payment_charge_id: payment.telegram_payment_charge_id)
      end
      payment.update!(refunded_at: Time.current)
    end

    # Cancels (or re-enables) renewal of the user's current subscription
    def set_renewal_canceled!(user, canceled)
      payment = user.current_payment
      return false unless payment&.is_recurring

      # Telegram's docs don't say which of the subscription's charge IDs this wants, so try both
      charge_ids = [payment.telegram_payment_charge_id, payment.subscription_charge_id].compact.uniq
      charge_ids.each_with_index do |charge_id, i|
        Telegram.bot.async(false) do
          Telegram.bot.edit_user_star_subscription(user_id: user.api_id, telegram_payment_charge_id: charge_id,
                                                   is_canceled: canceled)
        end
        break
      rescue Telegram::Bot::Error
        raise if i == charge_ids.size - 1
      end

      payment.update!(renewal_canceled_at: canceled ? Time.current : nil)
    end

    ### Telegram UI

    # Menu button next to the message box in the user's DMs, opening the Mini App
    def setup_private_chat(chat_api_id)
      return unless mini_app_url

      Telegram.bot.set_chat_menu_button(
        chat_id: chat_api_id,
        menu_button: { type: 'web_app', text: '⚙️ Settings', web_app: { url: mini_app_url } }
      )
    rescue Telegram::Bot::Error => e
      TelegramTools.logger.warn("Couldn't set menu button for chat #{chat_api_id}: #{e.message}")
    end

    def consent_keyboard
      { inline_keyboard: [[{ text: "✅ I'm 18+ and agree", callback_data: CONSENT_DATA }]] }
    end

    def paywall_keyboard(user)
      rows = [[{ text: "⭐ Subscribe · #{price} Stars / 30 days", url: invoice_link(user) }]]
      rows << [settings_button] if mini_app_url
      { inline_keyboard: rows }
    end

    def settings_keyboard
      { inline_keyboard: [[settings_button]] } if mini_app_url
    end

    def forget_keyboard
      { inline_keyboard: [[{ text: '🗑 Yes, forget our DMs', callback_data: FORGET_DATA }]] }
    end

    # Message texts in data/premium/*.html.erb (Telegram HTML)
    def text(name, **locals)
      template = Rails.root.join("data/premium/#{name}.html.erb").read
      ERB.new(template, trim_mode: '-').result_with_hash(
        bot_name:, price:, support_contact:, retention_days: DmSetting::RETENTION_DAYS,
        default_retention_days: DmSetting::DEFAULT_RETENTION_DAYS, **locals
      ).strip
    end

    def format_date(time)
      time.utc.strftime('%-d %b %Y')
    end

    private

    # Paid with an invoice link for this user, at the current price
    def current_invoice?(user, payload:, currency:, total_amount:)
      currency == CURRENCY && payload == invoice_payload(user) && total_amount == price
    end

    def settings_button
      { text: '⚙️ Personality & settings', web_app: { url: mini_app_url } }
    end
  end
end
