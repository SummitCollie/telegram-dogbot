# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FlareSolverrApi do
  let(:url) { 'https://example.fandom.com/wiki/Dogs' }
  let(:conn) { instance_double(Faraday::Connection) }
  let(:response_body) do
    { 'status' => 'ok', 'message' => 'Challenge solved!',
      'solution' => { 'url' => url, 'status' => 200, 'response' => '<html>dogs</html>' } }.to_json
  end

  before do
    allow(described_class).to receive_messages(
      config: ActiveSupport::OrderedOptions[uri_base: 'http://127.0.0.1:8191'],
      connection: conn
    )
    allow(conn).to receive(:post) { instance_double(Faraday::Response, body: response_body) }
  end

  describe '.enabled?' do
    it 'is true when uri_base is configured' do
      expect(described_class).to be_enabled
    end

    it 'is false without config' do
      allow(described_class).to receive(:config).and_return(nil)

      expect(described_class).not_to be_enabled
    end
  end

  describe '.get' do
    it 'returns the page HTML' do
      expect(described_class.get(url)).to eq '<html>dogs</html>'
    end

    it 'sends a request.get command' do
      described_class.get(url)

      expect(conn).to have_received(:post) do |path, body|
        expect(path).to eq 'v1'
        expect(JSON.parse(body)).to eq(
          'cmd' => 'request.get', 'url' => url, 'maxTimeout' => described_class::SOLVE_TIMEOUT * 1000
        )
      end
    end

    {
      'FlareSolverr error' => { 'status' => 'error', 'message' => 'Error solving the challenge. Timeout' }.to_json,
      'blocked page' => { 'status' => 'ok', 'solution' => { 'status' => 403, 'response' => '<html/>' } }.to_json,
      'blank page' => { 'status' => 'ok', 'solution' => { 'status' => 200, 'response' => '' } }.to_json,
      'missing solution' => { 'status' => 'ok' }.to_json,
      'JSON array' => '[]',
      'non-JSON body' => '<html>502 Bad Gateway</html>'
    }.each do |description, body|
      it "raises Error for #{description}" do
        allow(conn).to receive(:post).and_return instance_double(Faraday::Response, body:)

        expect { described_class.get(url) }.to raise_error described_class::Error
      end
    end

    [Faraday::ConnectionFailed, Faraday::TimeoutError].each do |error_class|
      it "raises Error when request raises #{error_class}" do
        allow(conn).to receive(:post).and_raise error_class

        expect { described_class.get(url) }.to raise_error described_class::Error
      end
    end
  end
end
