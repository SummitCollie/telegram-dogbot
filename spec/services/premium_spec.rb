# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Premium do
  let(:user) { create(:user) }

  before { enable_premium(price_stars: 250) }

  describe '.enabled?' do
    it 'needs a positive price' do
      expect(described_class).to be_enabled

      enable_premium(price_stars: 0)
      expect(described_class).not_to be_enabled

      allow(described_class).to receive(:config).and_return(nil)
      expect(described_class).not_to be_enabled
    end
  end

  describe '.invoice_link' do
    it 'creates a Stars subscription invoice for the user' do
      bot = stub_telegram_bot(create_invoice_link: { 'ok' => true, 'result' => 'https://t.me/$abc' })

      expect(described_class.invoice_link(user)).to eq 'https://t.me/$abc'
      expect(bot).to have_received(:create_invoice_link).with(hash_including(
                                                                payload: "premium-v1:#{user.api_id}",
                                                                currency: 'XTR',
                                                                prices: [{ label: '30 days', amount: 250 }],
                                                                subscription_period: 2_592_000
                                                              ))
    end
  end

  describe '.checkout_error' do
    def checkout_error(**overrides)
      described_class.checkout_error(user, payload: "premium-v1:#{user.api_id}", currency: 'XTR', total_amount: 250,
                                           **overrides)
    end

    before { create(:dm_setting, user:) }

    it 'accepts a current invoice from a user who agreed to the terms' do
      expect(checkout_error).to be_nil
    end

    it 'refuses invoices for someone else, or at another price or currency' do
      expect(checkout_error(payload: 'premium-v1:123')).to match(/outdated/)
      expect(checkout_error(total_amount: 100)).to match(/outdated/)
      expect(checkout_error(currency: 'USD')).to match(/outdated/)
    end

    it "refuses users who haven't agreed to the terms" do
      user.dm_setting.update!(consented_at: nil)

      expect(checkout_error).to match(/agree to the terms/)
    end

    it 'refuses users who are already subscribed' do
      create(:star_payment, user:)

      expect(checkout_error).to match(/already subscribed/)
    end

    it 'refuses everything when disabled' do
      enable_premium(price_stars: 0)

      expect(checkout_error).to match(/isn't taking payments/)
    end
  end

  describe '.record_payment!' do
    let(:expiration) { 30.days.from_now.change(usec: 0) }
    let(:first_payment) do
      { 'currency' => 'XTR', 'total_amount' => 250, 'invoice_payload' => "premium-v1:#{user.api_id}",
        'telegram_payment_charge_id' => 'first', 'subscription_expiration_date' => expiration.to_i,
        'is_recurring' => true, 'is_first_recurring' => true }
    end

    it 'records a subscription payment' do
      payment = described_class.record_payment!(user, first_payment)

      expect(payment).to have_attributes(
        user:, telegram_payment_charge_id: 'first', subscription_charge_id: 'first', total_amount: 250,
        expires_at: expiration, is_recurring: true, is_first_recurring: true
      )
      expect(user).to be_premium
    end

    it 'links renewals to the first payment of the subscription' do
      described_class.record_payment!(user, first_payment)
      renewal = described_class.record_payment!(
        user, first_payment.merge('telegram_payment_charge_id' => 'second', 'is_first_recurring' => nil,
                                  'subscription_expiration_date' => (expiration + 30.days).to_i)
      )

      expect(renewal).to have_attributes(subscription_charge_id: 'first', is_first_recurring: false)
      expect(user.premium_until).to eq expiration + 30.days
    end

    it 'ignores repeated deliveries of the same payment' do
      described_class.record_payment!(user, first_payment)

      expect { described_class.record_payment!(user, first_payment) }.not_to change(StarPayment, :count)
    end

    it 'gives 30 days for payments without a subscription expiration date' do
      payment = described_class.record_payment!(user, first_payment.except('subscription_expiration_date'))

      expect(payment.expires_at).to be_within(1.minute).of(30.days.from_now)
    end
  end

  describe '.refund!' do
    it 'refunds through Telegram and ends access' do
      bot = stub_telegram_bot(refund_star_payment: { 'ok' => true })
      payment = create(:star_payment, user:)

      described_class.refund!(payment)

      expect(bot).to have_received(:refund_star_payment)
        .with(user_id: user.api_id, telegram_payment_charge_id: payment.telegram_payment_charge_id)
      expect(payment.reload).to be_refunded
      expect(user).not_to be_premium
    end
  end

  describe '.set_renewal_canceled!' do
    let!(:payment) do
      create(:star_payment, user:, telegram_payment_charge_id: 'renewal', subscription_charge_id: 'first')
    end

    it 'cancels and re-enables renewal' do
      bot = stub_telegram_bot(edit_user_star_subscription: { 'ok' => true })

      described_class.set_renewal_canceled!(user, true)
      expect(payment.reload).to be_renewal_canceled

      described_class.set_renewal_canceled!(user, false)
      expect(payment.reload).not_to be_renewal_canceled
      expect(bot).to have_received(:edit_user_star_subscription)
        .with(user_id: user.api_id, telegram_payment_charge_id: 'renewal', is_canceled: false)
    end

    it "retries with the subscription's first charge ID if Telegram rejects the latest one" do
      bot = stub_telegram_bot
      allow(bot).to receive(:edit_user_star_subscription) do |telegram_payment_charge_id:, **|
        raise Telegram::Bot::Error, 'Bad Request' if telegram_payment_charge_id == 'renewal'

        { 'ok' => true }
      end

      described_class.set_renewal_canceled!(user, true)

      expect(bot).to have_received(:edit_user_star_subscription).twice
      expect(payment.reload).to be_renewal_canceled
    end

    it 'raises if Telegram rejects both' do
      bot = stub_telegram_bot
      allow(bot).to receive(:edit_user_star_subscription).and_raise(Telegram::Bot::Error, 'Bad Request')

      expect { described_class.set_renewal_canceled!(user, true) }.to raise_error(Telegram::Bot::Error)
      expect(payment.reload).not_to be_renewal_canceled
    end

    it 'does nothing for users without a subscription' do
      expect(described_class.set_renewal_canceled!(create(:user), true)).to be false
    end
  end

  describe '.text' do
    it 'renders every message template' do
      payment = create(:star_payment, user:)
      %i[onboarding paywall forget paysupport terms privacy].each do |name|
        expect(described_class.text(name)).to be_present
      end
      expect(described_class.text(:welcome, paid_until: '1 Jan 2027')).to include '1 Jan 2027'
      expect(described_class.text(:subscription, owner: false, payment:, paid_until: '1 Jan 2027'))
        .to include('Premium until 1 Jan 2027', 'Renews automatically for 250 Stars')
      expect(described_class.text(:subscription, owner: true, payment: nil, paid_until: nil)).to include 'owner'
    end

    it 'mentions the price and retention options' do
      expect(described_class.text(:onboarding)).to include('250 Telegram Stars', 'after 2 days', 'up to 30')
      expect(described_class.text(:privacy)).to include('2, 7 or 30 days')
    end
  end

  describe '.mini_app_url' do
    it 'needs a public host' do
      allow(Rails.application.credentials).to receive(:ngrok_url).and_return('dev.example.com')
      expect(described_class.mini_app_url).to eq 'https://dev.example.com/mini_app'

      allow(Rails.application.credentials).to receive(:ngrok_url).and_return(nil)
      expect(described_class.mini_app_url).to be_nil
    end
  end
end
