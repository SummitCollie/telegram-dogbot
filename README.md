# <p align="center">DogBot 🐶</p>

<p align="center"><img src="README-image.png" /></p>
<p align="center">art by <a href="https://www.furaffinity.net/user/yookie/">Yookie</a></p>

<br />

# <p align="center">/summarize_chat</p>
Summarize recent messages sent in a group chat.

Defaults to a neutral style, but a custom style can be provided:

### Custom style
> /summarize_chat `as a script for a podcast hosted by talking dogs`

# <p align="center">/summarize_url</p>
Attempts to summarize the main content of a web page.

Defaults to a neutral style, but a custom style can be provided:

### Custom style
> /summarize_url `https://example.com/news_article` `as though it's being presented as evidence in a court case`

>**EXHIBIT A: E. coli Outbreak Linked to McDonald's Quarter Pounders**
>
>**SUMMARY OF KEY FINDINGS**
>
>1. **Outbreak Overview**: An E. coli outbreak linked to McDonald's Quarter Pounders has led to at least 49 illnesses across 10 states, including one death.
>2. **Source of Contamination**: A specific ingredient has not been confirmed as the source of the outbreak,
>
> `...`

# <p align="center">/vibe_check</p>
Analyze chat members' moods

> • Summit: 💻 📊 🤖 / inquisitive, methodical, redundant\
> • SomeUser: 😍 ✨ 💖 / enamored, zealous, effusive\
> • AnotherUser: 😩 📉 😒 / despondent, lethargic, irritable\
> • `...`

# <p align="center">/translate `french hola mi amigo`</p>
Translates the text to requested language, or English by default.

Alternatively, just reply to any message from the chat and type `/translate` to translate that message.

Supported languages (using suggested model Aya-23):

> Arabic, Chinese (simplified & traditional), Czech, Dutch, English, French, German, Greek, Hebrew, Hindi, Indonesian, Italian, Japanese, Korean, Persian, Polish, Portuguese, Romanian, Russian, Spanish, Turkish, Ukrainian, and Vietnamese

# <p align="center">/chat_stats</p>
Print statistics about the chat (only knows about stuff that's happened since bot was added to room)

```
📊 Chat Stats
  • Total Messages: 100
  • Last 2 days: 40 (40%)

🗣 Top Yappers - 2 days
  1. SomeUser / 30 msgs (75%)
  2. Summit / 10 msgs (25%)

⭐ Top Yappers - all time
  1. Summit / 70 msgs (70%)
  2. SomeUser / 30 msgs (30%)
```
<br />

# Features & Ideas
- [x] LLM chatroom summarization
  - [x] Aware of reply threads
  - [x] Aware of media presence (photo/video/etc) & captions on media
  - [ ] Aware of current date/time and times of chat messages
  - [x] "Vibe check" summary of users' moods
- [x] Translate messages & replied messages between different languages
- [x] Summarize URLs
  - [x] If `/summarize_url` command is followed by a URL
  - [x] or `/summarize_url` command is a reply to another msg containing a URL
- [x] Talk to the bot - send a message tagging bot using `@itsUsername`
  - [ ] Aware of current date/time and times of chat messages
- [x] Nightly auto-delete of all chat data > 2 days old
- [x] Opt-out feature: globally ignores a given user across all chatrooms (no fun)
- [ ] Automatically transcribe all voice messages sent in the chat & translate to English
- [ ] User settings/personalization
  - [ ] Allow users to add a very short "bio" to be included with their messages in prompts
        so LLM functions use correct pronouns etc.
- [ ] Jannie features
  - [ ] Granular authorization: only admins/mods can execute commands, etc.
  - [ ] Customizable old-message-deletion timeframe

<br />

# Deployment
Designed to be deployed on Heroku with HuggingFace as the LLM API provider, but should be adaptable to anything.

* Handles 8000+ messages/day on 1x basic dyno with the cheapest Postgres ($7/month and $5/month respectively).
* HuggingFace Pro offers an OpenAI-compatible API for $9/month.

## Steps
1. Copy the master key encrypting your rails prod credentials [config/credentials/production.key](config/credentials/production.key) and make it available on your server as an environment variable `RAILS_MASTER_KEY`.
2. You can also set `RAILS_SERVE_STATIC_FILES` to `disabled` if you want.
3. Set up nightly data auto-delete:

### Auto-delete old data nightly
A rake task [`rake nightly_data_purge`](lib/tasks/nightly_data_purge.rake) is set up to purge old messages & other data from the DB. This is intended to be run nightly by a [Heroku Scheduler](https://devcenter.heroku.com/articles/scheduler) task, but you could use any task scheduling system to run it.

Add the free Heroku Scheduler addon to your app and then configure it with:
1. Run every day at 12:00am UTC (or whenever)
2. Run command: `rake nightly_data_purge`

<br />

# Local Development
## Install
1. Install postgres, ruby, bundler, heroku CLI.
2. `bundle install`
3. Setup database or whatever.
4. Configure options in rails credentials (example: [credentials.sample.yml](./config/credentials.sample.yml)).
  - App expects two credentials files:
    - `config/credentials/production.yml.enc` (`config/credentials/production.key`) is for production only
    - `config/credentials.yml.enc` (`config/master.key`) is for dev & test

## Run local dev env in poll mode (no webhook)
* `just run`

  aka

* `heroku local --procfile=Procfile.dev`

## Run local dev env in async/webhook mode
Only use this if you want to locally test the webhooks mode used in production for some reason (requires ngrok).

1. Add your `ngrok_url` and `telegram_secret_token` to rails development credentials.
2. Start server with `rails s`.
3. After you're done, run `Telegram.bot.delete_webhook` in a `rails c` console to delete the webhook so poll mode works again.

## Run linter & tests
* `just test`

  (aka `rubocop` and `rspec` in parallel)
