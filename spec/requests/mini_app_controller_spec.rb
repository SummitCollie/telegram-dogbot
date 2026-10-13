# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MiniAppController do
  let(:telegram_user) { { id: 4242, first_name: 'Sam', username: 'sam' } }
  let(:user) { User.find_by(api_id: 4242) }

  before do
    enable_premium(price_stars: 250)
    stub_telegram_bot
  end

  def init_data(user = telegram_user)
    fields = { 'auth_date' => Time.current.to_i.to_s, 'user' => user.to_json }
    URI.encode_www_form(fields.merge('hash' => MiniAppAuth.signature(fields)))
  end

  def api(method, path, params = nil)
    public_send(method, "/mini_app/api/#{path}", params: params&.to_json,
                                                 headers: { 'Authorization' => "tma #{init_data}",
                                                            'Content-Type' => 'application/json' })
    response.parsed_body
  end

  describe 'GET /mini_app' do
    it 'serves the page' do
      get '/mini_app'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq 'text/html'
      expect(response.body).to include 'telegram-web-app.js'
      expect(response.headers['Content-Security-Policy']).to include 'https://telegram.org'
    end
  end

  describe 'authentication' do
    it 'rejects requests without genuine initData' do
      get '/mini_app/api/state', headers: { 'Authorization' => 'tma user=%7B%22id%22%3A1%7D&hash=abc' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'is unavailable when premium is disabled' do
      enable_premium(price_stars: 0)

      api(:get, 'state')

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET state' do
    it 'creates the user and returns everything the page needs' do
      json = api(:get, 'state')

      expect(user).to have_attributes(first_name: 'Sam', username: 'sam')
      expect(json).to include(
        'user' => { 'first_name' => 'Sam' }, 'consented' => false, 'stored_messages' => 0,
        'premium' => include('active' => false, 'owner' => false, 'price' => 250, 'until' => nil),
        'settings' => include('bot_name' => nil, 'reply_length' => 'normal', 'creativity' => 2,
                              'double_texting' => true, 'retention_days' => 2)
      )
      expect(json['options']).to include('retention_days' => [2, 7, 30], 'reply_lengths' => %w[short normal long],
                                         'creativity_levels' => 5)
      expect(json['options']['presets'].first).to include('key' => 'dogbot', 'bot_name' => 'DogBot')
    end

    it 'shows the subscription' do
      api(:get, 'state')
      payment = create(:star_payment, user:, renewal_canceled_at: Time.current)

      json = api(:get, 'state')

      expect(json['premium']).to include('active' => true, 'until' => payment.expires_at.iso8601,
                                         'recurring' => true, 'renewal_canceled' => true)
    end
  end

  describe 'POST consent' do
    it 'records consent' do
      expect(api(:post, 'consent')).to include('consented' => true)
      expect(user.dm_setting).to be_consented
    end
  end

  describe 'PATCH settings' do
    let(:settings) do
      { bot_name: ' Rex ', persona: 'A grumpy cat', user_name: '', user_bio: 'they/them', reply_length: 'short',
        creativity: 4, double_texting: false, retention_days: 7 }
    end

    it 'requires consent' do
      api(:patch, 'settings', settings:)

      expect(response).to have_http_status(:forbidden)
    end

    context 'when consented' do
      before { api(:post, 'consent') }

      it 'saves settings, with blank text meaning default' do
        json = api(:patch, 'settings', settings:)

        expect(response).to have_http_status(:ok)
        expect(json['settings']).to include('bot_name' => 'Rex', 'user_name' => nil, 'retention_days' => 7)
        expect(user.dm_setting).to have_attributes(
          bot_name: 'Rex', persona: 'A grumpy cat', user_name: nil, user_bio: 'they/them', reply_length: 'short',
          creativity: 4, double_texting: false, retention_days: 7
        )
      end

      it 'rejects invalid settings' do
        json = api(:patch, 'settings', settings: { retention_days: 1 })

        expect(response).to have_http_status(:unprocessable_content)
        expect(json['error']).to match(/Retention days/)
      end

      it 'ignores fields that are not settings' do
        api(:patch, 'settings', settings: { consented_at: nil, user_id: 1, bot_name: 'Rex' })

        expect(user.dm_setting).to have_attributes(bot_name: 'Rex', consented?: true)
      end

      it 'resets settings' do
        api(:patch, 'settings', settings:)

        json = api(:post, 'settings/reset')

        expect(json['settings']).to include('bot_name' => nil, 'persona' => nil, 'retention_days' => 7)
      end
    end
  end

  describe 'POST forget' do
    it "deletes the user's DM history" do
      api(:get, 'state')
      chat = private_chat_for(user)
      create_list(:message, 3, chat_user: create(:chat_user, chat:, user:))

      json = api(:post, 'forget')

      expect(json).to include('forgotten' => 3, 'stored_messages' => 0)
      expect(chat.messages).to be_empty
    end
  end

  describe 'POST invoice' do
    before { allow(Premium).to receive(:invoice_link).and_return('https://t.me/$invoice') }

    it 'returns an invoice link for consenting users' do
      api(:post, 'consent')

      expect(api(:post, 'invoice')).to eq('link' => 'https://t.me/$invoice')
    end

    it 'requires consent' do
      api(:post, 'invoice')

      expect(response).to have_http_status(:forbidden)
    end

    it "refuses users who're already premium" do
      api(:post, 'consent')
      create(:star_payment, user:)

      api(:post, 'invoice')

      expect(response).to have_http_status(:conflict)
    end
  end

  describe 'POST renewal' do
    before { api(:post, 'consent') }

    it 'cancels or re-enables renewal' do
      allow(Premium).to receive(:set_renewal_canceled!).and_return(true)

      api(:post, 'renewal', canceled: true)

      expect(response).to have_http_status(:ok)
      expect(Premium).to have_received(:set_renewal_canceled!).with(user, true)
    end

    it 'fails without a subscription' do
      api(:post, 'renewal', canceled: true)

      expect(response).to have_http_status(:conflict)
    end

    it 'reports Telegram errors' do
      create(:star_payment, user:)
      allow(Telegram.bot).to receive(:edit_user_star_subscription).and_raise(Telegram::Bot::Error, 'nope')

      json = api(:post, 'renewal', canceled: true)

      expect(response).to have_http_status(:bad_gateway)
      expect(json['error']).to match(/Telegram/)
    end
  end
end
