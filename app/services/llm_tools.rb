# frozen_string_literal: true

class LLMTools
  def self.messages_to_yaml(messages)
    messages.map do |message|
      result = {
        id: message.id,
        user: message.user.first_name,
        text: message.text
      }

      result[:reply_to] = message.reply_to_message.id if messages.include?(message.reply_to_message)
      result[:attachment] = message.attachment_type.to_s if message.attachment_type.present?

      result
    end.to_yaml
  end

  def self.summarize_prompt
    @summarize_prompt ||= File.read('data/llm_prompts/summarize.txt')
  end
end
