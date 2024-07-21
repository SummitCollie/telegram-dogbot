# DogBot 🐶

## TODO
* AI summarizer
* Rake task which auto-deletes old messages
* Some UI to jump to previous summary in telegram (next summary btn would be cool too)

## Install
1. Install ruby, bundler, heroku CLI.
2. `bundle install`
3. Setup database or whatever.
4. Configure options in rails credentials (see [credentials.sample.yml](./config/credentials.sample.yml)).

## Run local dev environment
* `just run`

  or

* `heroku local --procfile=Procfile.dev`

## Run linter & tests
* `just test`

  (just runs `rubocop` and `rspec` in parallel)
