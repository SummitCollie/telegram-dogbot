if Rails.env == "production"
  Rake::Task['telegram:bot:set_webhook'].invoke
end
