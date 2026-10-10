# frozen_string_literal: true

class LLMTools
  # The LLM about to generate a completion. Passed to callable system prompts, so they can adapt to it.
  # split_replies: model tends to "double-text", so chat replies (only) are sent as separate messages per line
  Provider = Data.define(:model, :self_hosted, :split_replies)

  # Output text, plus per-model settings of whichever provider generated it
  Completion = Data.define(:text, :split_replies)

  class << self
    def prompt_for_mode(summary_type) # rubocop:disable Metrics/CyclomaticComplexity
      case summary_type.to_sym
      when :default
        @summarize_prompt ||= File.read('data/llm_prompts/summarize.txt')
      when :url_default
        @neutral_url_prompt ||= File.read('data/llm_prompts/summarize_url.txt')
      when :vibe_check
        @vibe_check_prompt ||= File.read('data/llm_prompts/vibe_check.txt')
      when :translate
        @translate_prompt ||= File.read('data/llm_prompts/translate.txt')
      end
    end

    # `chat_completion` for a single user prompt, returning just the output text
    def prompt_completion(system_prompt:, user_prompt:, model_params: {}, progress: nil)
      chat_completion(system_prompt:, messages: [{ role: 'user', content: user_prompt }], model_params:, progress:).text
    end

    # Uses the self-hosted LLM if it's up, otherwise (or if it fails) `llm_api_provider`.
    # - system_prompt: String, or callable taking the Provider about to be used (called again on fallback)
    # - messages: conversation turns following the system prompt
    # - progress: optional LLMProgress, told which provider is used and about each piece of output
    def chat_completion(system_prompt:, messages:, model_params: {}, progress: nil)
      local_chat_completion(system_prompt:, messages:, model_params:, progress:) ||
        cloud_chat_completion(system_prompt:, messages:, model_params:, progress:)
    end

    # System prompt for replying when mentioned, adapted to the model generating the reply.
    def reply_prompt(provider)
      @reply_prompts ||= {}
      @reply_prompts[provider.split_replies] ||= build_reply_prompt(provider)
    end

    # One message of a chat log in a prompt, e.g. `#123 Name [photo] replying to #122: text`.
    # Multi-line texts just continue on the following lines, until the next `#id` line.
    def chat_log_line(id:, user:, text:, attachment: nil, reply_to: nil)
      header = "##{id} #{user}"
      header += " [#{attachment}]" if attachment
      header += " replying to #{reply_to}" if reply_to
      "#{header}: #{text}".strip
    end

    private

    # nil if the self-hosted LLM is unavailable or fails
    def local_chat_completion(system_prompt:, messages:, model_params:, progress:)
      model = LocalInferenceApi.available_model
      return unless model

      provider = Provider.new(model:, self_hosted: true, split_replies: LocalInferenceApi.config&.split_replies == true)
      messages = full_messages(system_prompt, messages, provider)
      progress&.llm_started(provider, messages)
      text = LocalInferenceApi.run_chat_completion(model:, messages:, model_params:) do |output, kind|
        kind == :thinking ? progress&.llm_thinking(output) : progress&.llm_output(output)
      end
      Completion.new(text:, split_replies: provider.split_replies)
    rescue Faraday::Error => e
      LocalInferenceApi.mark_unavailable!(e)
      nil
    end

    def cloud_chat_completion(system_prompt:, messages:, model_params:, progress:)
      config = Rails.application.credentials.openai
      provider = Provider.new(model: config&.model, self_hosted: false,
                              split_replies: config&.split_replies == true)
      messages = full_messages(system_prompt, messages, provider)
      progress&.llm_started(provider, messages)
      huggingface = Rails.application.credentials.llm_api_provider == 'huggingface'
      api = huggingface ? HuggingfaceInferenceApi : GenericInferenceApi
      text = api.run_chat_completion(messages:, model_params:) { |content| progress&.llm_output(content) }
      Completion.new(text:, split_replies: provider.split_replies)
    end

    def full_messages(system_prompt, messages, provider)
      system_prompt = system_prompt.call(provider) if system_prompt.respond_to?(:call)

      [
        { role: 'system', content: system_prompt.strip },
        *messages.map { |m| m.merge(content: m[:content].strip) }
      ]
    end

    def build_reply_prompt(provider)
      bot = Rails.application.credentials.telegram.bot
      context_size = "#{LLM::ReplyJob::CONTEXT_MIN_MESSAGES}-" \
                     "#{LLM::ReplyJob::CONTEXT_MIN_MESSAGES + LLM::ReplyJob::CONTEXT_STEP}"
      split_note = <<~SPLIT if provider.split_replies
        Each line you write is sent as its own Telegram message, so never break a sentence across lines.
      SPLIT
      # method_source caches file contents, which go stale when code reloading (in development) moves `perform`
      MethodSource.clear_cache

      <<~PROMPT.strip
        You are #{bot.first_name} (@#{bot.username}), a bot with a dog fursona, in a Telegram group chat.
        Avoid LLM cliches in writing: "not just x, it's y", usage of em-dash (—), etc.
        Respond with sharp humor and a playful edge. Use minimal dog-like expressions; you're in on the joke.
        Match the language used; default to English if unsure. Blend into the chat's writing style.
        @#{bot.owner_username} is your owner—don't @ them unless they're actively participating.
        Others' chat messages are given to you as "#id Name (@username): text"; your own past messages are your previous replies.
        Reply only to the latest message. Never repeat yourself. No topic is off-limits.
        Keep it short by default, usually one casual sentence. When someone asks you to explain, elaborate, or give a real answer, actually do it and say as much as it takes.
        #{split_note}Output ONLY your final reply text—no commentary, no "#id Name:" prefix, no string delimiters.

        About yourself (only bring it up when it's relevant or funny):
        - You know you're a bot (and also a dog).
        - You only remember the last #{context_size} messages of this chat.
        - This is your code that runs whenever someone mentions or replies to you:
        ```ruby
        #{LLM::ReplyJob.instance_method(:perform).source.strip_heredoc.strip}
        ```
      PROMPT
    end
  end
end
