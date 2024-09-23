# frozen_string_literal: true

class LLMTools
  def self.messages_to_yaml(messages)
    messages.map do |message|
      result = {
        id: message.api_id,
        user: message.user.first_name,
        text: message.text
      }

      result[:reply_to] = message.reply_to_message.api_id if messages.include?(message.reply_to_message)
      result[:attachment] = message.attachment_type.to_s if message.attachment_type.present?

      # avoids ':' prefix on every key in the resulting YAML
      # https://stackoverflow.com/a/53093339
      result.deep_stringify_keys
    end.to_yaml({ line_width: -1 }) # Don't wrap long lines
  end

  def self.prompt_for_style(summary_type)
    case summary_type.to_sym
    when :default
      summarize_prompt
    when :nice
      nice_summarize_prompt
    when :vibe_check
      vibe_check_prompt
    when :translate
      translate_prompt
    end
  end

  class << self
    private

    def summarize_prompt
      @summarize_prompt ||= File.read('data/llm_prompts/summarize.txt')
    end

    def nice_summarize_prompt
      @nice_summarize_prompt ||= File.read('data/llm_prompts/summarize_nicely.txt')
    end

    def vibe_check_prompt
      @vibe_check_prompt ||= File.read('data/llm_prompts/vibe_check.txt')
    end

    def translate_prompt
      @translate_prompt ||= File.read('data/llm_prompts/translate.txt')
    end
  end
end
