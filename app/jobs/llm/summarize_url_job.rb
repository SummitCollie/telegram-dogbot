# frozen_string_literal: true

require 'open-uri'
require 'rubygems'
require 'readability'

module LLM
  class SummarizeUrlJob < ApplicationJob
    rescue_from FuckyWuckies::SummarizeJobFailure, with: :handle_error

    def perform(db_chat, url, style)
      @db_chat = db_chat

      title, author, html = parse_page(url)
      result_text = llm_summarize(title, author, html, style)

      send_output_message(result_text)
    end

    private

    def parse_page(url)
      source = OpenURI.open_uri(url).read
      result = Readability::Document.new(source, remove_empty_nodes: true)
      [result.title, result.author, result.content]
    rescue OpenURI::HTTPError => e
      code, err_message = e.io.status

      message = case code.to_i
                when 403
                  'DogBot server was blocked from accessing the URL :('
                else
                  'Unable to load URL :('
                end

      raise FuckyWuckies::SummarizeJobFailure.new(
        severity: Logger::Severity::ERROR,
        db_chat: @db_chat,
        frontend_message: "#{message}\n(#{code}: #{err_message.downcase})",
        sticker: :dead_two
      ), 'LLM API error: ' \
         "chat api_id=#{@db_chat.id} title=#{@db_chat.title}", cause: e
    end

    def llm_summarize(title, author, html, style)
      system_prompt = style.blank? ? LLMTools.prompt_for_style(:url_default) : custom_style_system_prompt(style)
      system_prompt = "#{system_prompt.strip}\n\n" \
                      "Guessed title: #{title.presence || '?'}\n" \
                      "Guessed author: #{author.presence || '?'}"

      puts "----------system prompt:\n#{system_prompt}"
      puts "----------user_prompt:\n#{html}"

      output = LLMTools.run_chat_completion(system_prompt:, user_prompt: html)

      raise FuckyWuckies::SummarizeJobFailure.new, 'Blank output' if output.blank?

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

    def custom_style_system_prompt(style)
      # TODO
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
