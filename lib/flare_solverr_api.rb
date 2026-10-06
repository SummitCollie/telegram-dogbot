# frozen_string_literal: true

# Optional self-hosted FlareSolverr, which loads pages in a real browser to get past
# Cloudflare's JS challenges. Only used as a fallback when fetching a URL directly gets blocked,
# since spinning up a browser is slow.
# https://github.com/FlareSolverr/FlareSolverr#usage
class FlareSolverrApi
  OPEN_TIMEOUT = 3 # seconds
  SOLVE_TIMEOUT = 60 # seconds FlareSolverr may spend loading the page & solving challenges

  # Page couldn't be loaded through FlareSolverr
  class Error < StandardError; end

  class << self
    def config
      Rails.application.credentials.flaresolverr
    end

    def enabled?
      config&.uri_base.present?
    end

    # Returns the page's HTML
    def get(url)
      body = { cmd: 'request.get', url:, maxTimeout: SOLVE_TIMEOUT * 1000 }
      # FlareSolverr responds with HTTP 500 + a JSON error message when solving fails, so don't raise on status
      page_html(JSON.parse(connection.post('v1', body.to_json).body))
    rescue Faraday::Error, JSON::ParserError => e
      raise Error, "#{e.class}: #{e.message}"
    end

    private

    def page_html(result)
      solution = result['solution'] if result.is_a?(Hash) && result['status'] == 'ok'
      raise Error, "FlareSolverr error: #{result.to_s.truncate(200)}" unless solution.is_a?(Hash)
      raise Error, "Page loaded with HTTP #{solution['status']}" if solution['status'].to_i >= 400

      html = solution['response']
      raise Error, 'Blank page' unless html.is_a?(String) && html.present?

      html
    end

    def connection
      timeout = SOLVE_TIMEOUT + 10 # let FlareSolverr report its own timeout first
      Faraday.new(url: config.uri_base, request: { timeout:, open_timeout: OPEN_TIMEOUT }) do |f|
        f.headers['Content-Type'] = 'application/json'
      end
    end
  end
end
