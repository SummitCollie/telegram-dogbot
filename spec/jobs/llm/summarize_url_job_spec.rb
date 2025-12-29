# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LLM::SummarizeUrlJob do
  # rubocop:disable RSpec/InstanceVariable
  describe '#perform' do
    let(:chat) { create(:chat) }
    let(:url) { 'http://example.com/article' }
    let(:style) { 'as a commercial for a competing product' }
    let(:html_page) do
      <<~HTMLPAGE.strip
        <!doctype html>
        <html>
        <head>
          <title>Best Dog Treats</title>
        </head>
        <body>
        <article>
          <header>
            <h1 class="headline">Best Dog Treats</h1>
            <div class="byline">
              <address class="author">By <a rel="author" href="/author/john-dog">John Dog</a></address>#{' '}
              on <time pubdate datetime="2000-01-01" title="August 28th, 2011">8/28/11</time>
            </div>
          </header>

          <div class="article-content">
            <p>This is an article about dog treats. Or is it?</p>
            <p>What else can we say? The real story is in the mind of the reader.</p>
          </div>
        </article>
        </body>
        </html>
      HTMLPAGE
    end
    let(:minified_html_page) do
      '<div><div><p>This is an article about dog treats. Or is it?</p>' \
        '<p>What else can we say? The real story is in the mind of the reader.</p></div></div>'
    end

    let(:expected_system_prompt_neutral) do
      <<~PROMPT.strip
        #{File.read('data/llm_prompts/summarize_url.txt').strip}

        Guessed title: Best Dog Treats
        Guessed author: John Dog
      PROMPT
    end
    let(:expected_system_prompt_custom) do
      <<~PROMPT.strip
        SUMMARY_STYLE=#{style}
        Summarize the main content of the provided HTML in the specified SUMMARY_STYLE.
        Focus on key ideas and important details, ignoring ads, links, and unrelated sections.
        If unreadable (e.g., paywalls, errors), respond with "Error loading URL: [reason]."
        Limit summary to 150-300 words. Only provide the summary text, no commantary.

        Guessed title: Best Dog Treats
        Guessed author: John Dog
      PROMPT
    end

    before do
      allow(LLMTools).to receive(:run_chat_completion).and_return 'LLM generated summary text'

      bot_double = instance_double('Telegram.bot', send_message: true, send_sticker: true, reset: true)
      allow(Telegram).to receive(:bot).and_return bot_double

      @open_uri_double = instance_double('OpenURI::OpenRead', read: html_page)
      allow(OpenURI).to receive(:open_uri).and_return(@open_uri_double)
    end

    context 'when provided with a custom style' do
      it 'chooses prompt for custom style and injects style properly' do
        described_class.perform_now(chat, url, style)

        expect(LLMTools).to have_received(:run_chat_completion).with(
          system_prompt: expected_system_prompt_custom,
          user_prompt: anything
        )
      end

      it 'minifies HTML for the user prompt' do
        described_class.perform_now(chat, url, style)

        expect(LLMTools).to have_received(:run_chat_completion).with(
          system_prompt: anything,
          user_prompt: minified_html_page
        )
      end
    end

    context 'when NOT provided with a custom style' do
      it 'uses prompt for default neutral style' do
        # Make sure it works with blank strings too
        described_class.perform_now(chat, url, ' ')
        described_class.perform_now(chat, url, nil)

        expect(LLMTools).to have_received(:run_chat_completion).once.with(
          system_prompt: expected_system_prompt_neutral,
          user_prompt: anything
        ).twice
      end

      it 'minifies HTML in user prompt' do
        described_class.perform_now(chat, url, '')

        expect(LLMTools).to have_received(:run_chat_completion).with(
          system_prompt: anything,
          user_prompt: minified_html_page
        )
      end
    end

    context 'when URL summarization is successful' do
      it 'sends result message in chat' do
        described_class.perform_now(chat, url, style)

        expect(Telegram.bot).to have_received(:send_message).with(
          chat_id: chat.api_id,
          protect_content: false,
          text: 'LLM generated summary text'
        )
      end

      it 'saves bot output as a Message in DB' do
        expect do
          described_class.perform_now(chat, url, nil)
        end.to change(Message, :count).by 1

        expect(Message.order(:date).last).to have_attributes(
          api_id: -1,
          text: 'LLM generated summary text'
        )
      end
    end

    context 'when URL summarization fails' do
      before do
        allow(LLMTools).to receive(:run_chat_completion).and_raise Faraday::Error
      end

      it 'responds in chat with "LLM error" message' do
        described_class.perform_now(chat, url, 'some style')

        expect(Telegram.bot).to have_received(:send_message).once.with(
          chat_id: chat.api_id,
          parse_mode: anything,
          text: 'LLM error! Page is probably too long :('
        )
      end
    end

    context 'when LLM output is blank' do
      before do
        allow(LLMTools).to receive(:run_chat_completion).and_return ' '
      end

      it 'responds in chat with "blank output" error' do
        described_class.perform_now(chat, url, nil)

        expect(Telegram.bot).to have_received(:send_message).once.with(
          chat_id: chat.api_id,
          parse_mode: anything,
          text: 'Error: blank LLM output :('
        )
      end
    end

    context 'when URL loading fails' do
      before do
        io_double = double(status: %w[403 Forbidden])
        allow(@open_uri_double)
          .to receive(:read)
          .and_raise OpenURI::HTTPError.new(
            '403 Forbidden',
            io_double
          )
      end

      it 'responds in chat with error including HTTP status code' do
        described_class.perform_now(chat, url, nil)

        expect(Telegram.bot).to have_received(:send_message).once.with(
          chat_id: chat.api_id,
          parse_mode: nil,
          text: "HTTPError: DogBot server was blocked from accessing the URL :(\n" \
                '(403: forbidden)'
        )
      end
    end
  end
  # rubocop:enable RSpec/InstanceVariable
end
