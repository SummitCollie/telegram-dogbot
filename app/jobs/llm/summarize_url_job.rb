# frozen_string_literal: true

require 'htmlcompressor'
require 'open-uri'
require 'rubygems'
require 'readability'

module LLM
  class SummarizeUrlJob < ApplicationJob
    rescue_from FuckyWuckies::SummarizeJobFailure, with: :handle_error

    # Ruby's default `User-Agent: Ruby` gets blocked by lots of sites
    REQUEST_HEADERS = {
      'User-Agent' => 'Mozilla/5.0 (compatible; DogBot/1.0; +https://github.com/SummitCollie/telegram-dogbot)',
      'Accept' => 'text/html,application/xhtml+xml',
      'Accept-Language' => 'en-US,en;q=0.9'
    }.freeze

    # Statuses bot protection (e.g. Cloudflare challenges) responds with: retry these through FlareSolverr
    BLOCKED_STATUSES = [403, 429, 503].freeze

    def perform(db_chat, url, style)
      @db_chat = db_chat
      @url = url
      @style = style

      result_text = LLMProgress.track(@db_chat, label: 'a page summary') do |progress|
        title, author, html = parse_page(url)
        llm_summarize(title, author, html, progress)
      end

      send_output_message(result_text)
    end

    private

    def parse_page(url)
      result = Readability::Document.new(fetch_page(url),
                                         remove_empty_nodes: true,
                                         tags: %w[div span p br table
                                                  tr td b i u blockquote
                                                  h1 h2 h3 h4 h5
                                                  ul ol li a])
      [result.title, result.author, result.content]
    rescue OpenURI::HTTPError => e
      err_code, err_message = e.io.status
      my_message = case err_code.to_i
                   when 403
                     'HTTPError: DogBot server was blocked from accessing the URL :('
                   else
                     'HTTPError: Unable to load URL :('
                   end

      raise FuckyWuckies::SummarizeJobFailure.new(
        severity: Logger::Severity::ERROR,
        db_chat: @db_chat,
        frontend_message: "#{my_message}\n(#{err_code}: #{err_message.downcase})",
        sticker: :dead_two
      ), 'LLM API error: ' \
         "chat api_id=#{@db_chat.id} title=#{@db_chat.title}", cause: e
    end

    def fetch_page(url)
      OpenURI.open_uri(url, REQUEST_HEADERS).read
    rescue OpenURI::HTTPError => e
      raise unless FlareSolverrApi.enabled? && BLOCKED_STATUSES.include?(e.io.status.first.to_i)

      fetch_page_with_flaresolverr(url, e)
    end

    # Raises the original HTTP error if FlareSolverr can't load the page either
    def fetch_page_with_flaresolverr(url, http_error)
      TelegramTools.logger.info("Blocked from #{url} (#{http_error.message}), retrying with FlareSolverr")
      FlareSolverrApi.get(url)
    rescue FlareSolverrApi::Error => e
      TelegramTools.logger.warn("FlareSolverr couldn't load #{url} (#{e.message})")
      raise http_error
    end

    def llm_summarize(title, author, html, progress)
      system_prompt = @style.blank? ? LLMTools.prompt_for_mode(:url_default) : custom_style_system_prompt
      system_prompt = "#{system_prompt.strip}\n\n" \
                      "Guessed title: #{title.presence || '?'}\n" \
                      "Guessed author: #{author.presence || '?'}"
      user_prompt = minify_html(html)

      TelegramTools.logger.debug("\n##### Summarize URL:\n" \
                                 "### System prompt:\n#{system_prompt}\n" \
                                 "### User prompt:\n#{user_prompt}")

      output = LLMTools.prompt_completion(system_prompt:, user_prompt:, progress:)

      if output.blank?
        raise FuckyWuckies::SummarizeJobFailure.new(
          severity: Logger::Severity::ERROR,
          db_chat: @db_chat,
          frontend_message: 'Error: blank LLM output :('
        ), "Blank LLM output summarizing URL: url=#{@url}"
      end

      output
    rescue Faraday::Error => e
      raise FuckyWuckies::SummarizeJobFailure.new(
        severity: Logger::Severity::ERROR,
        db_chat: @db_chat,
        frontend_message: 'LLM error! Page is probably too long :(',
        sticker: :dead
      ), 'LLM API error while summarizing URL: ' \
         "chat api_id=#{@db_chat.id} title=#{@db_chat.title}", cause: e
    end

    def custom_style_system_prompt
      <<~PROMPT.strip
        SUMMARY_STYLE=#{@style}
        Summarize the main content of the provided HTML in the specified SUMMARY_STYLE.
        Focus on key ideas and important details, ignoring ads, links, and unrelated sections.
        If unreadable (e.g., paywalls, errors), respond with "Error loading URL: [reason]."
        Limit summary to 150-300 words. Only provide the summary text, no commantary.
      PROMPT
    end

    def minify_html(html)
      compressor = HtmlCompressor::Compressor.new(
        remove_comments: true,
        remove_multi_spaces: true,
        remove_spaces_inside_tags: true,
        remove_intertag_spaces: true,
        remove_quotes: true,
        remove_script_attributes: true,
        remove_style_attributes: true,
        remove_link_attributes: true,
        remove_http_protocol: true,
        remove_https_protocol: true,
        preserve_line_breaks: false,
        simple_boolean_attributes: true
      )
      compressor.compress(html)
    end

    def send_output_message(text)
      TelegramTools.send_bot_message(@db_chat, text, protect_content: false)
    end

    def handle_error(error)
      # Respond in chat with error message
      TelegramTools.send_error_message(error, @db_chat.api_id)
    end
  end
end
