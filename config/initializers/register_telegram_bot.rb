# frozen_string_literal: true

Rake::Task['telegram:bot:set_webhook'].invoke if Rails.env.production?
