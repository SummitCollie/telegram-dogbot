# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  telegram_webhook TelegramWebhooksController

  # Premium settings Mini App (see MiniAppController)
  scope 'mini_app', controller: :mini_app, defaults: { format: :json } do
    get '/', action: :show, as: :mini_app, defaults: { format: :html }
    get 'api/state', action: :state
    post 'api/consent', action: :consent
    patch 'api/settings', action: :update_settings
    post 'api/settings/reset', action: :reset_settings
    post 'api/forget', action: :forget
    post 'api/invoice', action: :invoice
    post 'api/renewal', action: :renewal
  end
end
