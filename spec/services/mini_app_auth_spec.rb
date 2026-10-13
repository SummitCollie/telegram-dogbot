# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MiniAppAuth do
  let(:telegram_user) { { id: 4242, first_name: 'Rex', username: 'rex' } }
  let(:now) { Time.current }

  # Like Telegram.WebApp.initData
  def init_data(auth_date: now, **fields)
    fields = { auth_date: auth_date.to_i.to_s, query_id: 'AAH', user: telegram_user.to_json, **fields }
             .transform_keys(&:to_s)
    fields['hash'] ||= described_class.signature(fields)
    URI.encode_www_form(fields)
  end

  it 'returns the user from genuine initData' do
    expect(described_class.user(init_data, now:)).to include('id' => 4242, 'username' => 'rex')
  end

  it 'includes every field in the signature (e.g. signature)' do
    expect(described_class.user(init_data(signature: 'abc'), now:)).to include('id' => 4242)
  end

  it 'rejects tampered data' do
    data = init_data.sub('4242', '4243')

    expect(described_class.user(data, now:)).to be_nil
  end

  it 'rejects a wrong hash' do
    expect(described_class.user(init_data(hash: 'f' * 64), now:)).to be_nil
  end

  it 'rejects old data' do
    expect(described_class.user(init_data(auth_date: 2.days.ago), now:)).to be_nil
  end

  it 'rejects garbage' do
    expect(described_class.user(nil)).to be_nil
    expect(described_class.user('')).to be_nil
    expect(described_class.user('hash=abc&user=%7B')).to be_nil
  end
end
