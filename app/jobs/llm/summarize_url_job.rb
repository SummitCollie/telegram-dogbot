# frozen_string_literal: true

require 'htmlcompressor'
require 'open-uri'
require 'rubygems'
require 'readability'

module LLM
  class SummarizeUrlJob < ApplicationJob
    rescue_from FuckyWuckies::SummarizeJobFailure, with: :handle_error

    def perform(db_chat, url, style)
      @db_chat = db_chat
      @url = url
      @style = style

      title, author, html = parse_page(url)
      result_text = llm_summarize(title, author, html)

      send_output_message(result_text)
    end

    private

    def parse_page(url)
      source = OpenURI.open_uri(url).read
      result = Readability::Document.new(source,
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

    def llm_summarize(title, author, html)
      system_prompt = @style.blank? ? LLMTools.prompt_for_mode(:url_default) : custom_style_system_prompt
      system_prompt = "#{system_prompt.strip}\n\n" \
                      "Guessed title: #{title.presence || '?'}\n" \
                      "Guessed author: #{author.presence || '?'}"
      user_prompt = minify_html(html)

      TelegramTools.logger.debug("\n##### Summarize URL:\n" \
                                 "### System prompt:\n#{system_prompt}\n" \
                                 "### User prompt:\n#{user_prompt}")

      output = LLMTools.run_chat_completion(system_prompt:, user_prompt:)

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
      Telegram.bot.send_message(
        chat_id: @db_chat.api_id,
        protect_content: false,
        text:
      )
      TelegramTools.store_bot_output(@db_chat, text)
    end

    def handle_error(error)
      # Respond in chat with error message
      TelegramTools.send_error_message(error, @db_chat.api_id)
    end
  end
end
