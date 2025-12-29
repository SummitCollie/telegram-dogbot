# frozen_string_literal: true

class HuggingfaceInferenceApi
  class << self
    def run_chat_completion(system_prompt:, user_prompt:, model_params:)
      # TODO: seems to break without log_errors: true for some reason
      # OpenAI HTTP Error (spotted in ruby-openai 7.3.1): Invalid URL: missing field `name`
      client = OpenAI::Client.new(log_errors: true)

      client.add_headers('x-use-cache' => 'false')
      # client.add_headers('x-wait-for-model' => 'true')

      messages = [
        { role: 'system', content: system_prompt.strip },
        { role: 'user', content: user_prompt.strip }
      ]

      result = StringIO.new
      client.chat(parameters: {
        model: Rails.application.credentials.openai.model,
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
