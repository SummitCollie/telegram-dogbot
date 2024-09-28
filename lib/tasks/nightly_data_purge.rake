# frozen_string_literal: true

require 'logger'

# Intended to be run by Heroku Scheduler (set that up manually like below)
# [Every day at 12:00 UTC / Run Command `rake nightly_data_purge`]
desc 'Deletes old telegram messages & other data from database'
task nightly_data_purge: :environment do
  logger = Logger.new(Rails.env.test? ? '/dev/null' : $stdout)

  delete_older_than = 2.days.ago

  logger.info("Purging data from before #{delete_older_than}...")

  num_messages_deleted = DogbotUtils.delete_messages(older_than: delete_older_than)
  num_summaries_deleted = DogbotUtils.delete_chat_summaries(older_than: delete_older_than)

  logger.info(
    "Finished nightly data purge at #{Time.current} -- [Deleted " \
    "#{num_messages_deleted} Messages / " \
    "#{num_summaries_deleted} ChatSummaries]"
  )
end
