# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LocalInferenceApi do
  include ActiveSupport::Testing::TimeHelpers

  let(:model_name) { 'hf.co/LessThanThreeAI/Qwen3.8-27B-Humanlike-Chat-GGUF:Q6_K' }
  let(:config) do
    ActiveSupport::OrderedOptions[
      uri_base: 'http://10.0.0.11:11434',
      model_match: 'Humanlike-Chat',
      request_params: { think: false, options: { num_ctx: 32768, temperature: 1.0, top_k: 20 } }
    ]
  end
  let(:conn) { instance_double(Faraday::Connection) }
  let(:tags_body) { { 'models' => [{ 'name' => 'qwen3.6:27b' }, { 'name' => model_name }] }.to_json }

  before do
    allow(described_class).to receive_messages(config:, connection: conn)
    allow(conn).to receive(:get).with('api/tags') { instance_double(Faraday::Response, body: tags_body) }
  end

  describe '.available_model' do
    it 'returns matching installed model' do
      expect(described_class.available_model).to eq model_name
    end

    it 'probes with a short timeout' do
      described_class.available_model

      expect(described_class).to have_received(:connection).with(timeout: described_class::PROBE_TIMEOUT)
    end

    it 'returns nil when no matching model is installed' do
      allow(conn).to receive(:get)
        .and_return instance_double(Faraday::Response, body: { 'models' => [{ 'name' => 'gemma4:31b' }] }.to_json)

      expect(described_class.available_model).to be_nil
    end

    [Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError].each do |error_class|
      it "returns nil when probe raises #{error_class}" do
        allow(conn).to receive(:get).and_raise error_class

        expect(described_class.available_model).to be_nil
      end
    end

    {
      'non-JSON body' => '<html>models Humanlike-Chat</html>',
      'JSON without models' => '{}',
      'JSON array' => '[{"name": "Humanlike-Chat"}]',
      'models without names' => '{"models": [{"model": "x"}, "Humanlike-Chat", null, {"name": 5}]}'
    }.each do |description, body|
      it "returns nil for unexpected response: #{description}" do
        allow(conn).to receive(:get).and_return instance_double(Faraday::Response, body:)

        expect(described_class.available_model).to be_nil
      end
    end

    it 'returns nil without probing when not configured' do
      allow(described_class).to receive(:config).and_return nil

      expect(described_class.available_model).to be_nil
      expect(conn).not_to have_received(:get)
    end

    it 'returns nil without probing when uri_base is blank' do
      config.uri_base = ''

      expect(described_class.available_model).to be_nil
      expect(conn).not_to have_received(:get)
    end

    it 'caches result until RECHECK_INTERVAL passes' do
      described_class.available_model
      described_class.available_model
      expect(conn).to have_received(:get).once

      travel(described_class::RECHECK_INTERVAL + 1.second) { described_class.available_model }
      expect(conn).to have_received(:get).twice
    end

    it 'picks up server becoming available on next probe' do
      allow(conn).to receive(:get).and_raise Faraday::ConnectionFailed
      expect(described_class.available_model).to be_nil

      allow(conn).to receive(:get) { instance_double(Faraday::Response, body: tags_body) }
      travel(described_class::RECHECK_INTERVAL + 1.second) do
        expect(described_class.available_model).to eq model_name
      end
    end
  end

  describe '.mark_unavailable!' do
    it 'makes available_model nil until next probe, then re-probes' do
      described_class.available_model
      described_class.mark_unavailable!(Faraday::TimeoutError.new('timed out'))

      expect(described_class.available_model).to be_nil
      expect(conn).to have_received(:get).once

      travel(described_class::RECHECK_INTERVAL + 1.second) do
        expect(described_class.available_model).to eq model_name
      end
    end
  end

  describe '.run_chat_completion' do
    let(:messages) { [{ role: 'system', content: 'sys' }, { role: 'user', content: 'hi' }] }
    let(:posted) { {} }
    # Ollama streams one JSON object per line; network chunks don't line up with lines
    let(:chunks) do
      [
        %({"message":{"role":"assistant","content":" lol"},"done":false}\n{"message":{"role":"assistant","con),
        %(tent":"\\nno "},"done":false}\n),
        %({"message":{"role":"assistant","content":""},"done":true,"eval_count":2}) # no trailing newline
      ]
    end

    before do
      allow(conn).to receive(:post) do |path, body, &block|
        posted.merge!(path:, body: JSON.parse(body, symbolize_names: true))
        req = Struct.new(:options).new(Faraday::RequestOptions.new)
        block.call(req)
        chunks.each { |chunk| req.options.on_data.call(chunk, chunk.bytesize) }
      end
    end

    def run(model_params: {})
      described_class.run_chat_completion(model: model_name, messages:, model_params:)
    end

    it 'joins streamed content (lines split across chunks), and strips it' do
      expect(run).to eq "lol\nno"
    end

    it 'posts to /api/chat with the long chat timeout' do
      run

      expect(posted[:path]).to eq 'api/chat'
      expect(described_class).to have_received(:connection).with(timeout: described_class::CHAT_TIMEOUT)
    end

    it 'sends messages with request_params from config' do
      run

      expect(posted[:body]).to eq(
        model: model_name,
        messages:,
        stream: true,
        think: false,
        options: { num_ctx: 32768, temperature: 1.0, top_k: 20 }
      )
    end

    it 'merges model_params into options, ignoring cloud model name' do
      run(model_params: { model: 'cloud-model', temperature: 0.9 })

      expect(posted[:body]).to include(
        model: model_name,
        options: { num_ctx: 32768, temperature: 0.9, top_k: 20 }
      )
    end

    it 'works without request_params' do
      config.request_params = nil

      expect(run).to eq "lol\nno"
      expect(posted[:body]).to include(options: {})
    end

    it 'raises ResponseError (a Faraday::Error) when Ollama streams an error' do
      chunks << %(\n{"error":"model runner has unexpectedly stopped"}\n)

      expect { run }.to raise_error(described_class::ResponseError, /unexpectedly stopped/) { |e|
        expect(e).to be_a Faraday::Error
      }
    end

    it 'raises ResponseError for a malformed line' do
      chunks.replace(["<html>502 bad gateway</html>\n"])

      expect { run }.to raise_error(described_class::ResponseError, /Unexpected response/)
    end

    it 'lets HTTP errors through' do
      allow(conn).to receive(:post).and_raise Faraday::ResourceNotFound

      expect { run }.to raise_error Faraday::ResourceNotFound
    end

    it 'yields each piece of output content' do
      yielded = []
      described_class.run_chat_completion(model: model_name, messages:, model_params: {}) { |c| yielded << c }

      expect(yielded).to eq [' lol', "\nno "]
    end

    describe 'prompt speed (for ETAs)' do
      def final_chunk(evaluated:, cached:, seconds:)
        { done: true, prompt_eval_count: evaluated, prompt_eval_cached_count: cached,
          prompt_eval_duration: (seconds * 1e9).to_i }.to_json
      end

      it 'records uncached prompt tokens per second from final stats' do
        chunks.replace([final_chunk(evaluated: 3500, cached: 500, seconds: 10)])
        run

        expect(described_class.prompt_tokens_per_second).to eq 300.0
      end

      it 'ignores requests with too few uncached prompt tokens' do
        chunks.replace([final_chunk(evaluated: 3500, cached: 3400, seconds: 0.2)])
        run

        expect(described_class.prompt_tokens_per_second).to be_nil
      end
    end
  end

  describe '.loaded_model' do
    let(:ps_body) do
      { 'models' => [{ 'name' => 'other:7b' }, { 'name' => model_name, 'context_length' => 32768 }] }.to_json
    end

    before do
      allow(conn).to receive(:get).with('api/ps') { instance_double(Faraday::Response, body: ps_body) }
    end

    it "returns the model's info when loaded" do
      expect(described_class.loaded_model(model_name)).to eq('name' => model_name, 'context_length' => 32768)
      expect(described_class).to have_received(:connection).with(timeout: described_class::PROBE_TIMEOUT)
    end

    it 'returns nil when not loaded' do
      expect(described_class.loaded_model('not-loaded:1b')).to be_nil
    end

    it 'returns nil on errors or unexpected responses' do
      allow(conn).to receive(:get).with('api/ps').and_raise Faraday::ConnectionFailed
      expect(described_class.loaded_model(model_name)).to be_nil

      allow(conn).to receive(:get).with('api/ps') { instance_double(Faraday::Response, body: '<html>') }
      expect(described_class.loaded_model(model_name)).to be_nil
    end
  end

  describe '.connection' do
    before { allow(described_class).to receive(:connection).and_call_original }

    it 'connects to uri_base with given timeout, short connect timeout, raising on HTTP errors' do
      faraday = described_class.send(:connection, timeout: 42)

      expect(faraday.url_prefix.to_s).to eq 'http://10.0.0.11:11434/'
      expect(faraday.options.timeout).to eq 42
      expect(faraday.options.open_timeout).to eq described_class::PROBE_TIMEOUT
      expect(faraday.builder.handlers).to include Faraday::Response::RaiseError
    end
  end
end
