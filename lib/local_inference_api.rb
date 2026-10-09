# frozen_string_literal: true

# Self-hosted Ollama server, used opportunistically: only while it's reachable AND has a model
# matching `local_llm.model_match` installed (Ollama loads it on demand).
# Callers should fall back to the cloud provider when `available_model` is nil.
#
# Uses Ollama's native API rather than its OpenAI-compatible one, which can't set per-request
# `options` (num_ctx, top_k, ...) and doesn't report load/prompt processing stats.
# https://github.com/ollama/ollama/blob/main/docs/api.md
class LocalInferenceApi
  PROBE_TIMEOUT = 3 # seconds; also the connect timeout for chat requests
  CHAT_TIMEOUT = 240 # seconds per read: nothing is streamed while the model loads and reads the prompt
  RECHECK_INTERVAL = 1.minute
  MIN_TOKENS_FOR_SPEED = 500 # mostly-cached prompts don't say much about prompt processing speed
  MUTEX = Mutex.new

  # Error reported in Ollama's response body. A Faraday::Error, so callers fall back like for HTTP errors.
  class ResponseError < Faraday::Error; end

  class << self
    def config
      Rails.application.credentials.local_llm
    end

    def enabled?
      config&.uri_base.present?
    end

    # Name of the matching installed model if the local server is usable, otherwise nil.
    # Server is re-probed at most once per RECHECK_INTERVAL.
    def available_model
      return unless enabled?

      MUTEX.synchronize do
        update_model(probe_model) if @checked_at.nil? || @checked_at < RECHECK_INTERVAL.ago
        @model
      end
    end

    # Called when a request to the local server fails, so subsequent requests
    # go straight to the fallback until the next probe
    def mark_unavailable!(error)
      MUTEX.synchronize do
        TelegramTools.logger.warn("Local LLM request failed (#{error.class}: #{error.message})")
        update_model(nil)
      end
    end

    # `model_params` are merged into Ollama's `options` (e.g. temperature).
    # Yields each piece of streamed output content, if given a block.
    def run_chat_completion(model:, messages:, model_params:)
      result = +''
      each_streamed_chunk('api/chat', chat_request_body(model, messages, model_params)) do |chunk|
        content = chunk.dig('message', 'content').to_s
        result << content
        yield content if block_given? && content.present?
        record_prompt_speed(chunk) if chunk['done']
      end

      result.strip
    end

    # Info about `model` if it's currently loaded in memory ({ 'name', 'context_length', ... }), otherwise nil.
    # https://github.com/ollama/ollama/blob/main/docs/api.md#list-running-models
    def loaded_model(model)
      body = JSON.parse(connection(timeout: PROBE_TIMEOUT).get('api/ps').body)
      models = body.is_a?(Hash) ? Array(body['models']) : []

      models.find { |m| m.is_a?(Hash) && m['name'] == model }
    rescue Faraday::Error, JSON::ParserError
      nil
    end

    # Uncached prompt tokens processed per second, measured on the last big enough request (for ETAs)
    attr_reader :prompt_tokens_per_second

    # For tests
    def reset!
      MUTEX.synchronize do
        @model = nil
        @checked_at = nil
        @prompt_tokens_per_second = nil
      end
    end

    private

    # `local_llm.request_params` holds model-specific Ollama params, e.g. { think: false, options: { num_ctx: ... } }
    def chat_request_body(model, messages, model_params)
      params = config.request_params.to_h.deep_symbolize_keys
      options = { **params.fetch(:options, {}), **model_params }

      { **params, model:, messages:, stream: true, options: }
    end

    # Yields each parsed line of Ollama's streamed (newline-delimited JSON) response
    def each_streamed_chunk(path, body, &)
      buffer = +''

      connection(timeout: CHAT_TIMEOUT).post(path, body.to_json) do |req|
        req.options.on_data = proc do |data, _bytes_received|
          buffer << data
          parse_complete_lines(buffer, &)
        end
      end

      buffer << "\n" # last line may not end with a newline
      parse_complete_lines(buffer, &)
    end

    # Final chunk has stats: https://github.com/ollama/ollama/blob/main/docs/api.md#response-10
    def record_prompt_speed(final_chunk)
      processed = final_chunk['prompt_eval_count'].to_i - final_chunk['prompt_eval_cached_count'].to_i
      seconds = final_chunk['prompt_eval_duration'].to_i / 1e9
      return if processed < MIN_TOKENS_FOR_SPEED || seconds <= 0

      @prompt_tokens_per_second = processed / seconds
    end

    def parse_complete_lines(buffer)
      while (line = buffer.slice!(/\A.*\n/))
        yield parse_chunk(line) if line.strip.present?
      end
    end

    def parse_chunk(line)
      chunk = JSON.parse(line)
      raise ResponseError, "Unexpected response: #{line.truncate(200)}" unless chunk.is_a?(Hash)
      raise ResponseError, "Ollama error: #{chunk['error']}" if chunk['error']

      chunk
    rescue JSON::ParserError
      raise ResponseError, "Unexpected response: #{line.truncate(200)}"
    end

    def connection(timeout:)
      Faraday.new(url: config.uri_base, request: { timeout:, open_timeout: PROBE_TIMEOUT }) do |f|
        f.headers['Content-Type'] = 'application/json'
        f.response :raise_error
      end
    end

    def probe_model
      body = JSON.parse(connection(timeout: PROBE_TIMEOUT).get('api/tags').body)
      models = body.is_a?(Hash) ? Array(body['models']) : []

      models.filter_map { |m| m['name'] if m.is_a?(Hash) }
            .find { |name| name.is_a?(String) && name.include?(config.model_match) }
    rescue Faraday::Error, JSON::ParserError
      nil
    end

    def update_model(model)
      if model != @model
        TelegramTools.logger.info(
          model ? "Local LLM available, switching to: #{model}" : 'Local LLM unavailable, switching to fallback provider'
        )
      end

      @model = model
      @checked_at = Time.current
    end
  end
end
