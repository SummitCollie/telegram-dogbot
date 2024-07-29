# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChatSummary do
  describe '#after_find' do
    it 'deletes any in-progress ChatSummary started > 5 minutes ago'
  end
end
