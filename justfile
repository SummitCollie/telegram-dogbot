# Postgres + bot in poll mode (process-compose TUI)
run:
  nix run .#devenv

test:
  rubocop & rspec & wait

edit-creds-dev:
  rails credentials:edit

edit-creds-prod:
  rails credentials:edit --environment=production

dev-db-shell:
  psql -h localhost -p 5434 -d dogbot_development

dev-delete-database:
  rm -rf .postgres/

# For debugging webhooks/async mode locally (use `rails s` to start server)
start-ngrok:
  ngrok http --url $(rails runner "puts Rails.application.credentials.ngrok_url") 3000

# Use these instead of the original `bundle <mutate>` commands
# https://github.com/inscapist/ruby-nix?tab=readme-ov-file#2-how-to-bundle
bundle-add gemname:
  bundle add {{gemname}} --skip-install
bundle-update gemname:
  bundle lock --update {{gemname}}
bundle-update-all:
  bundle lock --update
bundle-check-updates:
  bundle outdated
bundle-install-and-lock:
  bundle lock
  bundix -l
