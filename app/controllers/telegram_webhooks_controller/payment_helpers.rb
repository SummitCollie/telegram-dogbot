# frozen_string_literal: true

class TelegramWebhooksController
  # Telegram Stars payments for premium (see Premium)
  module PaymentHelpers
    private

    def payment_message?
      raw_message = raw_update['message'] || {}
      raw_message.key?('successful_payment') || raw_message.key?('refunded_payment')
    end

    def handle_payment_message
      raw_message = raw_update['message']
      if raw_message['successful_payment']
        handle_successful_payment(raw_message['successful_payment'])
      else
        handle_refunded_payment(raw_message['refunded_payment'])
      end
    end

    def handle_successful_payment(successful_payment)
      db_user = create_or_update_user
      payment = Premium.record_payment!(db_user, successful_payment)
      renewal = payment.is_recurring && !payment.is_first_recurring
      TelegramTools.logger.info("Premium payment: user api_id=#{db_user.api_id} amount=#{payment.total_amount} " \
                                "until=#{payment.expires_at} renewal=#{renewal}")
      return if renewal # Telegram shows a message about it already

      Premium.setup_private_chat(chat.id)
      send_welcome(db_user)
    end

    def handle_refunded_payment(refunded_payment)
      payment = StarPayment.find_by(telegram_payment_charge_id: refunded_payment['telegram_payment_charge_id'])
      payment.update!(refunded_at: Time.current) if payment && !payment.refunded?
    end

    # Lets the owner know someone needs payment help (if the owner has started a DM with the bot)
    def notify_owner_of_paysupport(words)
      owner = User.find_by(username: Rails.application.credentials.telegram.bot.owner_username)
      return if owner.nil? || owner.api_id == from.id

      name = [from.first_name, ("(@#{from.username})" if from.username)].compact.join(' ')
      Telegram.bot.send_message(
        chat_id: owner.api_id,
        text: "💳 /paysupport from #{name}, user ID #{from.id}:\n#{words.join(' ').presence || '(no message)'}"
      )
    rescue Telegram::Bot::Error => e
      TelegramTools.logger.warn("Couldn't forward /paysupport to owner: #{e.message}")
    end

    # Owner's /refund: lists recent payments, or refunds one by its charge ID
    def run_refund(charge_id)
      return send_recent_payments if charge_id.blank?

      payment = StarPayment.find_by(telegram_payment_charge_id: charge_id)
      return send_html_message('No payment with that charge ID') unless payment
      return send_html_message('Already refunded') if payment.refunded?

      Premium.refund!(payment)
      send_html_message("Refunded #{payment.total_amount}⭐ to user #{payment.user.api_id}")
    rescue Telegram::Bot::Error => e
      send_html_message("Refund failed: #{ERB::Util.html_escape(e.message)}")
    end

    def send_recent_payments
      lines = StarPayment.includes(:user).order(created_at: :desc).limit(10).map do |payment|
        user = payment.user
        "<code>#{ERB::Util.html_escape(payment.telegram_payment_charge_id)}</code> " \
          "#{ERB::Util.html_escape(user.username ? "@#{user.username}" : user.first_name)} " \
          "#{payment.total_amount}⭐ #{Premium.format_date(payment.created_at)}#{' (refunded)' if payment.refunded?}"
      end

      send_html_message("Recent payments (refund one with <code>/refund CHARGE_ID</code>):\n\n" \
                        "#{lines.join("\n").presence || 'none'}")
    end
  end
end
