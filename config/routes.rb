Rails.application.routes.draw do
  # Main pages
  root "pages#home"
  get "success", to: "pages#success"

  # API endpoints
  namespace :api do
    post "generate", to: "generate#create"
    post "checkout", to: "checkout#create"
    get "download", to: "downloads#show"
    get "run", to: "runs#show"
    get "cleanup", to: "cleanup#show"
    post "cleanup", to: "cleanup#create"

    namespace :stripe do
      post "webhook", to: "webhooks#create"
    end
  end

  # Sidekiq Web UI (optional - can be protected in production)
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
