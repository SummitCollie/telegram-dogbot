# frozen_string_literal: true

require 'rails_helper'
require 'telegram/bot/rspec/integration/rails'

RSpec.describe TelegramWebhooksController, telegram_bot: :rails do
  include ActiveJob::TestHelper

  let(:user_id) { 4242 }
  let(:from) { { id: user_id, is_bot: false, first_name: 'Sam', username: 'sam' } }
  let(:private_chat) { { id: user_id, type: 'private', first_name: 'Sam' } }
  let(:db_user) { User.find_by(api_id: user_id) }

  before do
    enable_premium(price_stars: 250)
    allow(Premium).to receive_messages(invoice_link: 'https://t.me/$invoice', mini_app_url: 'https://bot.example.com/mini_app')
  end

  def requests(action) = Telegram.bot.requests[action]
  def sent_texts = requests(:sendMessage).pluck(:text)

  def dm(text = 'hi', **options)
    dispatch message: { message_id: rand(1..100_000), date: Time.current.to_i, from:, chat: private_chat, text:,
                        **options }
  end

  def press(data, message_id: 77)
    dispatch callback_query: { id: 'cb1', from:, data:,
                               message: { message_id:, date: Time.current.to_i, chat: private_chat, text: '...' } }
  end

  def premium_user!
    user = create_premium_user(api_id: user_id, first_name: 'Sam', username: 'sam')
    private_chat_for(user)
    user
  end

  context 'when premium is disabled' do
    before { enable_premium(price_stars: 0) }

    it 'says DMs do nothing, like before' do
      dm

      expect(sent_texts.sole).to include 'This bot is for group chats'
      expect(Message.count).to eq 0
    end
  end

  describe 'onboarding' do
    it "asks new users to confirm they're 18+ and agree to the terms, without storing their message" do
      dm

      expect(requests(:sendMessage).sole).to include(
        chat_id: user_id, parse_mode: 'HTML', text: a_string_including("I'm an AI"),
        reply_markup: Premium.consent_keyboard
      )
      expect(Message.count).to eq 0
    end

    it 'records consent, then offers the subscription' do
      dm

      press(Premium::CONSENT_DATA)

      expect(db_user.dm_setting).to be_consented
      expect(requests(:answerCallbackQuery).sole).to include(text: 'Thanks!')
      expect(requests(:editMessageReplyMarkup).sole).to include(message_id: 77, reply_markup: { inline_keyboard: [] })
      expect(requests(:sendMessage).last).to include(
        text: a_string_including('DMs with me are premium'),
        reply_markup: { inline_keyboard: [
          [{ text: '⭐ Subscribe · 250 Stars / 30 days', url: 'https://t.me/$invoice' }],
          [{ text: '⚙️ Personality & settings', web_app: { url: 'https://bot.example.com/mini_app' } }]
        ] }
      )
    end

    it 'shows the paywall to consenting users without premium' do
      create(:dm_setting, user: create(:user, api_id: user_id))

      dm

      expect(sent_texts.sole).to include 'DMs with me are premium'
      expect(Message.count).to eq 0
    end

    it '/start sets up the settings menu button' do
      dispatch_command_in_dm :start

      expect(requests(:setChatMenuButton).sole).to eq(
        chat_id: user_id,
        menu_button: { type: 'web_app', text: '⚙️ Settings', web_app: { url: 'https://bot.example.com/mini_app' } }
      )
      expect(sent_texts.sole).to include "I'm an AI"
    end
  end

  describe 'premium DMs' do
    before { premium_user! }

    it 'stores the message and replies to it (after a short delay)' do
      expect { dm('how are you') }.to have_enqueued_job(LLM::DirectReplyJob)
        .with(an_instance_of(Message)).at(a_value > Time.current)

      expect(Message.last).to have_attributes(text: 'how are you', chat: having_attributes(api_type: 'private_room'))
      expect(requests(:sendMessage)).to be_empty
    end

    it 'says it can only read text' do
      dispatch message: { message_id: 1, date: Time.current.to_i, from:, chat: private_chat,
                          photo: [{ file_id: 'x', file_unique_id: 'x', width: 1, height: 1 }] }

      expect(sent_texts.sole).to include 'I can only read text'
      expect(enqueued_jobs).to be_empty
    end

    it 'stores edits' do
      dm('helo', message_id: 5)
      dispatch edited_message: { message_id: 5, date: Time.current.to_i, from:, chat: private_chat, text: 'hello' }

      expect(Message.sole.text).to eq 'hello'
    end

    it '/start shows their subscription' do
      dispatch_command_in_dm :start

      expect(sent_texts.sole).to include('Premium until', 'Renews automatically for 250 Stars')
    end

    it '/settings opens the Mini App' do
      dispatch_command_in_dm :settings

      expect(requests(:sendMessage).sole).to include(reply_markup: { inline_keyboard: [[
                                                       { text: '⚙️ Personality & settings', web_app: { url: 'https://bot.example.com/mini_app' } }
                                                     ]] })
    end

    it '/forget asks first, then deletes their DM history' do
      dm('remember this')

      dispatch_command_in_dm :forget
      expect(requests(:sendMessage).last).to include(reply_markup: Premium.forget_keyboard)
      expect(Message.count).to eq 1

      press(Premium::FORGET_DATA)
      expect(Message.count).to eq 0
      expect(requests(:editMessageText).sole).to include(text: a_string_including('forgot our DM history (1 messages)'))
    end

    it 'stops a reply being streamed when the user presses stop' do
      allow(DraftStreamer).to receive(:stop)

      dispatch update_id: 1, stopped_message_generation: { chat: private_chat }

      expect(DraftStreamer).to have_received(:stop).with(user_id)
    end
  end

  describe 'payments' do
    def pre_checkout(**overrides)
      dispatch pre_checkout_query: { id: 'q1', from:, currency: 'XTR', total_amount: 250,
                                     invoice_payload: "premium-v1:#{user_id}", **overrides }
    end

    def successful_payment(**fields)
      dispatch message: {
        message_id: 9, date: Time.current.to_i, from:, chat: private_chat,
        successful_payment: { currency: 'XTR', total_amount: 250, invoice_payload: "premium-v1:#{user_id}",
                              telegram_payment_charge_id: 'charge1', provider_payment_charge_id: '',
                              subscription_expiration_date: 30.days.from_now.to_i, is_recurring: true,
                              is_first_recurring: true, **fields }
      }
    end

    before { create(:dm_setting, user: create(:user, api_id: user_id)) }

    it 'approves valid checkouts' do
      pre_checkout

      expect(requests(:answerPreCheckoutQuery).sole).to eq(pre_checkout_query_id: 'q1', ok: true)
    end

    it 'refuses invalid ones with a reason' do
      pre_checkout(total_amount: 1)

      expect(requests(:answerPreCheckoutQuery).sole)
        .to include(pre_checkout_query_id: 'q1', ok: false, error_message: a_string_including('outdated'))
    end

    it 'records payments (with fields telegram-bot-types drops) and welcomes new subscribers' do
      successful_payment

      expect(db_user).to be_premium
      expect(db_user.star_payments.sole).to have_attributes(telegram_payment_charge_id: 'charge1', is_recurring: true)
      expect(db_user.premium_until).to be_within(1.minute).of(30.days.from_now)
      expect(sent_texts.sole).to include "You're in!"
      expect(requests(:setChatMenuButton).size).to eq 1
      expect(Message.count).to eq 0
    end

    it "doesn't welcome renewals" do
      successful_payment
      Telegram.bot.reset

      successful_payment(telegram_payment_charge_id: 'charge2', is_first_recurring: nil,
                         subscription_expiration_date: 60.days.from_now.to_i)

      expect(db_user.star_payments.count).to eq 2
      expect(db_user.premium_until).to be_within(1.minute).of(60.days.from_now) # from subscription_expiration_date
      expect(requests(:sendMessage)).to be_empty
    end

    it 'records refunds' do
      successful_payment

      dispatch message: { message_id: 10, date: Time.current.to_i, from:, chat: private_chat,
                          refunded_payment: { currency: 'XTR', total_amount: 250, telegram_payment_charge_id: 'charge1',
                                              invoice_payload: "premium-v1:#{user_id}" } }

      expect(db_user).not_to be_premium
    end

    it '/paysupport explains how to get help, and tells the owner' do
      owner = create(:user, username: Rails.application.credentials.telegram.bot.owner_username)

      dispatch_command_in_dm :paysupport, 'charged twice'

      expect(requests(:sendMessage).first).to include(chat_id: user_id, text: a_string_including('Payment support'))
      expect(requests(:sendMessage).last).to include(chat_id: owner.api_id,
                                                     text: a_string_including('Sam (@sam)', 'charged twice'))
    end
  end

  describe '/refund' do
    let(:owner_from) do
      { id: 1, is_bot: false, first_name: 'Owner', username: Rails.application.credentials.telegram.bot.owner_username }
    end
    let(:payment) { create(:star_payment, telegram_payment_charge_id: 'charge1') }

    def refund_command(*args, as: owner_from)
      dispatch message: { message_id: 1, date: Time.current.to_i, from: as, chat: { id: as[:id], type: 'private' },
                          text: ['/refund', *args].join(' ') }
    end

    it 'lists recent payments' do
      payment

      refund_command

      expect(sent_texts.sole).to include('<code>charge1</code>', '250⭐')
    end

    it 'refunds a payment by charge ID' do
      allow(Premium).to receive(:refund!)

      refund_command(payment.telegram_payment_charge_id)

      expect(Premium).to have_received(:refund!).with(payment)
      expect(sent_texts.sole).to include 'Refunded 250⭐'
    end

    it 'is only for the owner' do
      allow(Premium).to receive(:refund!)

      refund_command(payment.telegram_payment_charge_id, as: from)

      expect(Premium).not_to have_received(:refund!)
    end
  end

  describe '/privacy & /terms' do
    it 'shows them in DMs' do
      dispatch_command_in_dm :privacy
      dispatch_command_in_dm :terms

      expect(sent_texts).to match [a_string_including('Privacy notice'), a_string_including('Terms')]
    end

    it 'shows the privacy notice in (whitelisted) groups too' do
      allow(Rails.application.credentials).to receive(:whitelist_enabled).and_return(false)

      dispatch message: { message_id: 1, date: Time.current.to_i, from:,
                          chat: { id: -100, type: 'supergroup', title: 'Group' }, text: '/privacy' }

      expect(requests(:sendMessage).sole).to include(chat_id: -100, text: a_string_including('Privacy notice'))
    end
  end

  def dispatch_command_in_dm(command, *args)
    dm(["/#{command}", *args].join(' '))
  end
end
