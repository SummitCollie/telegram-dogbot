# <p align="center">DogBot 🐶</p>

<p align="center"><img src="README-image.png" /></p>

# Commands
## <p align="center">`/summarize`</p>
Summarize group chat messages sent since the last summary (or as many as possible)

> • The group discussed Nick's hilarious experience while watching the film "Zootopia" in a movie theater.
>
> • The conversation shifted to the topic of creativity, with AnonFur suggesting that everyone has some form of creative expression.
>
> `...`

## <p align="center">/summarize_nicely</p>
Like above but be very nice about it

> • Summit diligently worked on testing and improving 
their knowledge, inquiring about statistics multiple times to better comprehend the data.
>
> • Summit aesthetically shared a minimalist design element, adding a touch of simplicity and elegance to the conversation. ` // I posted a single emoji in the chat lol`
>
> `...`

## <p align="center">/vibe_check</p>
Analyze chat members' moods

> • Summit: 💻 📊 🤖 / inquisitive, methodical, redundant
>
> • SomeUser: 😍 ✨ 💖 / enamored, zealous, effusive
>
> • AnotherUser: 😩 📉 😒 / despondent, lethargic, irritable

## <p align="center">/translate `french hola mi amigo`</p>
Translates the text to requested language, or English by default.

Alternatively, just reply to any message from the chat and type `/translate` to translate that message.

Supported languages (using suggested model Aya-23):

> Arabic, Chinese (simplified & traditional), Czech, Dutch, English, French, German, Greek, Hebrew, Hindi, Indonesian, Italian, Japanese, Korean, Persian, Polish, Portuguese, Romanian, Russian, Spanish, Turkish, Ukrainian, and Vietnamese

## <p align="center">`/stats`</p>
Print statistics about the chat (only knows about stuff that's happened since bot was added to room)

```
📊 Chat Stats
  • Total Messages: 100
  • Last 2 days: 40 (40%)

🗣 Top Yappers (last 2 days):
  1. SomeUser / 30 msgs (75%)
  2. Summit / 10 msgs (25%)

⭐ Top Yappers (all time):
  1. Summit / 70 msgs (70%)
  2. SomeUser / 30 msgs (30%)
```

# Features & Ideas
- [x] LLM chatroom summarization
  - [x] Aware of reply threads
  - [x] Aware of media presence (photo/video/etc) & captions on media
  - [x] "Vibe check" summary of users' moods
- [x] Rake task to auto-delete chat data > 2 days old
- [x] Translate messages & replied messages between different languages
- [ ] Automatically transcribe all voice messages sent in the chat & translate to English
- [ ] Jannie features
  - [ ] Granular authorization: only admins/mods can execute commands, etc.
  - [ ] Customizable old-message-deletion timeframe
- [ ] Summarize links somehow?
  - [ ] Maybe if `/summarize` command is followed by a URL
  - [ ] or `/summarize` command is a reply to another msg containing a URL

# Deployment
Designed to be deployed on Heroku, but should be adaptable to any service.

1. Copy the master key encrypting your rails prod credentials [config/credentials/production.key](config/credentials/production.key) and make it available on your server as an environment variable `RAILS_MASTER_KEY`.
2. You can also set `RAILS_SERVE_STATIC_FILES` to `disabled` if you want.

## Purge data > 2 days old from DB using Heroku Scheduler
A rake task [`rake nightly_data_purge`](lib/tasks/nightly_data_purge.rake) is set up to purge old messages/users/other data from the DB. This is intended to be run nightly by a [Heroku Scheduler](https://devcenter.heroku.com/articles/scheduler) task, but you could use any task scheduling system to run it.

Add the free Heroku Scheduler addon to your app and then configure it with:
1. Run every day at 12:00am UTC
2. Run command: `rake nightly_data_purge`

# Local Development
## Install
1. Install postgres, ruby, bundler, heroku CLI.
2. `bundle install`
3. Setup database or whatever.
4. Configure options in rails credentials (example: [credentials.sample.yml](./config/credentials.sample.yml)).
  - App expects two credentials files:
    - `config/credentials/production.yml.enc` (`config/credentials/production.key`) is for production only
    - `config/credentials.yml.enc` (`config/master.key`) is for dev & test

### Optional: justfile convenience scripts
1. Install just
2. Copy `/justfile.sample` to `/justfile`, then edit any indicated values.
3. Or just copy the scripts from it into your favorite tool.

## Run local dev env (bot listener polls telegram, no webhook)
* `just run`

  aka

* `heroku local --procfile=Procfile.dev`

## Run linter & tests
* `just test`

  (aka `rubocop` and `rspec` in parallel)
