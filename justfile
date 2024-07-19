run:
  heroku local --procfile=Procfile.dev

test:
  rubocop & rspec & wait

edit-creds-dev:
  rails credentials:edit

edit-creds-prod:
  rails credentials:edit --environment=production
