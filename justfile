run:
  heroku local --procfile=Procfile.dev

test:
  rubocop & rspec & wait
