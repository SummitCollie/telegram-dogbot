# frozen_string_literal: true

Rspec.describe UserOptOutMgr do
  describe '#opt_out' do
    it 'sets user.opt_out flag to true'
    it 'deletes all saved messages from user'

    context 'when user has no existing record in DB' do
      it 'creates a user and sets opt_out flag to true'
    end
  end

  describe '#opt_in' do
    it 'sets user.opt_out flag to false'
  end
end
