# frozen_string_literal: true

require 'logger'

# Run nightly in production by a systemd timer (see nix/module.nix)
desc 'Deletes old telegram messages & other data from database'

task nightly_data_purge: :environment do
  logger = Logger.new(Rails.env.test? ? File::NULL : $stdout)

  # Premium DMs keep messages for longer if their user chose to (see DmSetting::RETENTION_DAYS)
  retention = DmSetting::DEFAULT_RETENTION_DAYS.days
  delete_older_than = retention.ago

  logger.info("Purging data from before #{delete_older_than} (or longer ago in DMs set to keep it longer)...")

  num_messages_deleted = DogbotUtils.delete_messages(default_retention: retention)
  num_summaries_deleted = DogbotUtils.delete_chat_summaries(older_than: delete_older_than)

  logger.info(
    "Finished nightly data purge at #{Time.current} -- [Deleted " \
    "#{num_messages_deleted} Messages / " \
    "#{num_summaries_deleted} ChatSummaries]"
  )
end
