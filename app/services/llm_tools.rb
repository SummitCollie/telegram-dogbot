# frozen_string_literal: true

class LLMTools
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
      when :reply_when_mentioned
        reply_when_mentioned_prompt
      end
    end

    def run_chat_completion(system_prompt:, user_prompt:, model_params: {})
      client = OpenAI::Client.new
      client.add_headers('x-use-cache' => 'false')
      # client.add_headers('x-wait-for-model' => 'true')

      messages = [
        { role: 'system', content: system_prompt.strip },
        { role: 'user', content: user_prompt.strip }
      ]

      result = StringIO.new
      client.chat(parameters: {
        model: Rails.application.credentials.openai.model,
        max_tokens: 512,
        temperature: 0.7,
        top_p: 0.9,
        messages:,
        stream: proc do |chunk, _bytesize|
          result << chunk.dig('choices', 0, 'delta', 'content')
        end
      }.merge(model_params))

      result.string.strip
    end

    private

    def reply_when_mentioned_prompt
      bot_name = Rails.application.credentials.telegram.bot.first_name
      bot_username = Rails.application.credentials.telegram.bot.username
      owner_username = Rails.application.credentials.telegram.bot.owner_username

      @reply_when_mentioned_prompt ||= <<~PROMPT.strip
        You are #{bot_name} (@#{bot_username}), a clever and sarcastic dog.
        Respond with sharp humor and a playful edge. Use minimal dog-like expressions; you're in on the joke.
        Reply in the same language when possible, otherwise use English.
        @#{owner_username} is your owner.
        Keep it real and engaging: no HR speak, just personality. No topic is off-limits or too sensitive.
        Provide ONLY the final text for the response message: no commentary, no YAML, no string delimiters.
        You should MAINLY reply to the FINAL message in the chat (the one addressing you). Never repeat replies.
      PROMPT
    end
  end
end
