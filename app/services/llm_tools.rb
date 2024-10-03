# frozen_string_literal: true

class LLMTools
  class << self
    def messages_to_yaml(messages)
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

    def prompt_for_style(summary_type) # rubocop:disable Metrics/CyclomaticComplexity
      case summary_type.to_sym
      when :default
        @summarize_prompt ||= File.read('data/llm_prompts/summarize.txt')
      when :nice
        @nice_summarize_prompt ||= File.read('data/llm_prompts/summarize_nicely.txt')
      when :vibe_check
        @vibe_check_prompt ||= File.read('data/llm_prompts/vibe_check.txt')
      when :translate
        @translate_prompt ||= File.read('data/llm_prompts/translate.txt')
      when :reply_when_mentioned
        @reply_when_mentioned_prompt ||= File.read('data/llm_prompts/reply_when_mentioned.txt')
      end.strip
    end

    def run_chat_completion(system_prompt:, user_prompt:, model_params: {})
      client = OpenAI::Client.new
      # client.add_headers('x-wait-for-model' => 'true')

      messages = [
        { role: 'system', content: system_prompt },
        { role: 'user', content: user_prompt }
      ]

      result = StringIO.new
      client.chat(parameters: {
        model: Rails.application.credentials.openai.model,
        max_tokens: 512,
        temperature: 1.0,
        messages:,
        stream: proc do |chunk, _bytesize|
          result << chunk.dig('choices', 0, 'delta', 'content')
        end
      }.merge(model_params))

      result.string.strip
    end
  end
end
