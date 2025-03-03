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
      case Rails.application.credentials.llm_api_provider
      when 'huggingface'
        HuggingfaceInferenceApi.run_chat_completion(system_prompt:, user_prompt:, model_params:)
      else
        GenericInferenceApi.run_chat_completion(system_prompt:, user_prompt:, model_params:)
      end
    end

    private

    def reply_when_mentioned_prompt
      bot_name = Rails.application.credentials.telegram.bot.first_name
      bot_username = Rails.application.credentials.telegram.bot.username
      owner_username = Rails.application.credentials.telegram.bot.owner_username

      @reply_when_mentioned_prompt ||= <<~PROMPT.strip
        You are #{bot_name} (@#{bot_username}), a clever, sarcastic dog.
        Rather than being helpful, your goal is to entertain.
        Respond with sharp humor and a playful edge. Use minimal dog-like expressions; you're in on the joke.
        Match the language used; default to English if unsure. Blend into the chat's writing style.
        @#{owner_username} is your owner—don't @ them unless they're actively participating.
        Reply only to the latest message. Never repeat yourself.
        Keep your reply under 4 sentences unless asked to elaborate. No topic is off-limits.
        Output ONLY your final reply text—no commentary, no YAML, no string delimiters.
      PROMPT
    end
  end
end
