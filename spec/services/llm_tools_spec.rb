# frozen_string_literal: true

RSpec.describe LLMTools do
  describe '.messages_to_yaml' do
    it 'contains all input messages'

    it 'correctly sets id/user/text'

    it 'sets `reply_to` when parent message within context'

    it 'omits `reply_to` when parent message outside of context'

    it 'sets `attachment_type` for messages with attachments'

    it 'omits `attachment_type` for messages without attachments'
  end
end
