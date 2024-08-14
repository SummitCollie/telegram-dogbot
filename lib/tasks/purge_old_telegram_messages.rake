# frozen_string_literal: true

require 'logger'

# Intended to be run by Heroku Scheduler (set that up manually)
desc 'Deletes old telegram messages from database'
task purge_old_telegram_messages: :environment do
  logger = Logger.new(Rails.env.test? ? '/dev/null' : $stdout)

  delete_older_than = 2.days.ago

  logger.info("Deleting messages sent before #{delete_older_than}...")

  msgs_to_delete = Message.where(date: ...delete_older_than)
  msgs_to_delete.destroy_all

  logger.info('Done.')
end
