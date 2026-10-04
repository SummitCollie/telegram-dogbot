# frozen_string_literal: true

# Telegram.bot double for specs that check what the bot sends.
# Behaves like the real client: runs `async` blocks, and send_message returns the sent message.
module TelegramBotDouble
  # Params of each send_message call, in order
  def telegram_sent_messages
    @telegram_sent_messages ||= []
  end

  def stub_telegram_bot(**other_methods)
    bot = instance_double('Telegram.bot', reset: true, **other_methods)
    next_message_id = 1_000_000

    allow(bot).to receive(:async) { |*, &block| block.call }
    allow(bot).to receive(:send_message) do |**params|
      telegram_sent_messages << params
      { 'ok' => true, 'result' => { 'message_id' => next_message_id += 1, 'date' => Time.current.to_i } }
    end
    allow(Telegram).to receive(:bot).and_return bot

    bot
  end
end

RSpec.configure { |config| config.include TelegramBotDouble }
