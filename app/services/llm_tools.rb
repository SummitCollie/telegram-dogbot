# frozen_string_literal: true

class LLMTools
  def self.messages_to_yaml(messages)
    messages.map do |message|
      result = {
        id: message.id,
        user: message.user.first_name,
        text: message.text
      }

      result.reply_to = message.reply_to_message.id if messages.include?(message.reply_to_message)
      result.attachment = message.attachment_type.to_s if message.attachment_type.present?

      result
    end.to_yaml
  end

  def self.summarize_prompt
    return @summarize_prompt if @summarize_prompt

    example_summary = File.read('data/example-summary-for-prompt.txt')
    @summarize_prompt = <<~TEXT
      You are a helpful chat bot who summarizes group chat messages.
      Your goal is to concisely highlight each chat member's stories and the general subjects discussed in the chat.
      Do not provide opinions or suggestions, simply extract and present the key points and main themes in a bulleted list.
      You will receive the messages in YAML format, but do not mention this in the summary.
      Do not add any notes or preface the summary with any message such as "This is a summary of the chat:"
      Your response should ONLY contain the bullet points of the summary.

      ---EXAMPLE SUMMARY---
      #{example_summary}
    TEXT
  end
end
