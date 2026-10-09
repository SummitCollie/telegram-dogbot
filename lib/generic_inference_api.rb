# frozen_string_literal: true

class GenericInferenceApi
  class << self
    # Yields each piece of streamed output content, if given a block
    def run_chat_completion(messages:, model_params:)
      client = OpenAI::Client.new(log_errors: true)

      result = StringIO.new
      client.chat(parameters: {
        model: Rails.application.credentials.openai.model,
        temperature: 1.0,
        top_p: 1,
        messages:,
        stream: proc do |chunk, _bytesize|
          content = chunk.dig('choices', 0, 'delta', 'content')
          result << content
          yield content if block_given? && content.present?
        end
      }.merge(model_params))

      result.string.strip
    end
  end
end
