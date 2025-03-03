# frozen_string_literal: true

class GenericInferenceApi
  class << self
    def run_chat_completion(system_prompt:, user_prompt:, model_params:)
      client = OpenAI::Client.new(log_errors: true)

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
  end
end
