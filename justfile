run:
  heroku local --procfile=Procfile.dev

test:
  rubocop & rspec & wait

# Solargraph
rebuild-gem-documentation:
  bundle exec yard gems

edit-creds-dev:
  rails credentials:edit

edit-creds-prod:
  rails credentials:edit --environment=production

# For debugging webhooks/async mode locally (use `rails s` to start server)
start-ngrok:
  ngrok http --url $(rails runner "puts Rails.application.credentials.ngrok_url") 3000
