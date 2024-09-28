# <p align="center">DogBot 🐶</p>

<p align="center"><img src="README-image.png" /></p>

## Commands
### `/summarize`
Summarize group chat messages sent since the last summary (or as many as possible)

### `/summarize_nicely`
Like above but be very nice about it

### `/vibe_check`
Analyze chat members' moods

### `/translate hola mi amigo`
Translates the text to English. Alternatively, just quote another message from the chat and type `/translate` to translate that message.

#### specify target language: `/translate spanish hello my friend`
Translate to a given language. Supported languages (using suggested model Aya-23):

> Arabic, Chinese (simplified & traditional), Czech, Dutch, English, French, German, Greek, Hebrew, Hindi, Indonesian, Italian, Japanese, Korean, Persian, Polish, Portuguese, Romanian, Russian, Spanish, Turkish, Ukrainian, and Vietnamese

### ~~`/stats`~~ (wip)
Print statistics about the chat (only knows about stuff that's happened since bot was added to room)

## Features & Ideas
- [x] LLM chatroom summarization
  - [x] Aware of reply threads
  - [x] Aware of media presence (photo/video/etc) & captions on media
  - [x] "Vibe check" summary of users' moods
  - [ ] Feed previous summaries back into LLM prompt for longer "memory"
    * (`/summarize_past_summaries` command?)
- [x] Rake task which auto-deletes old messages
- [x] Translate messages & quoted messages between different languages
- [ ] Automatically transcribe all voice messages sent in the chat & translate to English
- [ ] Jannie features
  - [ ] Granular authorization: only admins/mods can execute commands, etc.
  - [ ] Customizable old-message-deletion timeframe
- [ ] Summarize links somehow?
  - [ ] Maybe if `/summarize` command is followed by a URL
  - [ ] or `/summarize` command is a reply to another msg containing a URL

## Deployment
Designed to be deployed on Heroku, but should be adaptable to any service.

1. Copy the master key encrypting your rails prod credentials [config/credentials/production.key](config/credentials/production.key) and make it available on your server as an environment variable `RAILS_MASTER_KEY`.
2. You can also set `RAILS_SERVE_STATIC_FILES` to `disabled` if you want.

### Purge messages > 2 days old from DB using Heroku Scheduler
A rake task `rake purge_old_telegram_messages` is set up to purge old messages from the DB. This is intended to be run nightly by a [Heroku Scheduler](https://devcenter.heroku.com/articles/scheduler) task, but you could use any task scheduling system to run it.

Add the free Heroku Scheduler addon to your app and then configure it with:
1. Run every day at 12:00am UTC
2. Run command: `rake purge_old_telegram_messages`

### Heroku Scheduler
A rake task `rake purge_old_telegram_messages` is set up to purge old messages from the DB. This is intended to be run on a daily basis by a [Heroku Scheduler](https://devcenter.heroku.com/articles/scheduler) task.

## Local Development
### Install
1. Install postgres, ruby, bundler, heroku CLI.
2. `bundle install`
3. Setup database or whatever.
4. Configure options in rails credentials (example: [credentials.sample.yml](./config/credentials.sample.yml)).
  - App expects two credentials files:
    - `config/credentials/production.yml.enc` (`config/credentials/production.key`) is for production only
    - `config/credentials.yml.enc` (`config/master.key`) is for dev & test

#### Optional: justfile convenience scripts
1. Install just
2. Copy `/justfile.sample` to `/justfile`, then edit any indicated values.
3. Or just copy the scripts from it into your favorite tool.

### Run local dev env (bot listener polls telegram, no webhook)
* `just run`

  aka

* `heroku local --procfile=Procfile.dev`

### Run linter & tests
* `just test`

  (aka `rubocop` and `rspec` in parallel)
