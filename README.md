# DogBot 🐶

## Features
[ ] LLM chatroom summarization
  [x] Aware of reply threads
  [x] Aware of media presence (photo/video) & captions on media
  [ ] "Vibe check" summary of users' moods
[ ] LLM job queue system
[ ] Some UI to jump to previous summary in telegram (next summary btn would be cool too)
[ ] Rake task which auto-deletes old messages
[ ] Feed previous summaries back into LLM prompt for longer "memory"
[ ] Jannie features
  [ ] Granular authorization: only admins/mods can execute commands, etc.
  [ ] Customizable old-message-deletion timeframe
[ ] Summarize links somehow:
  [ ] Maybe if `/summarize` command is followed by a URL
  [ ] or `/summarize` command is a reply to another msg containing a URL

## Install
1. Install postgres, ruby, bundler, heroku CLI.
2. `bundle install`
3. Setup database or whatever.
4. Configure options in rails credentials (see [credentials.sample.yml](./config/credentials.sample.yml)).

## Run local dev environment
* `just run`

  or

* `heroku local --procfile=Procfile.dev`

## Run linter & tests
* `just test`

  (runs `rubocop` and `rspec` in parallel)
