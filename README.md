# DogBot 🐶

## TODO
* AI summarizer

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
