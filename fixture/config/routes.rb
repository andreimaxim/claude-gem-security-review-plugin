Rails.application.routes.draw do
  get "/health", to: "notes#health"
  resources :notes, only: [:index, :create, :show]
  get "/export", to: "notes#export"
  get "/preview", to: "notes#preview"
  get "/cache-status", to: "notes#cache_status"
  get "/stream", to: "streams#show"
  get "(/locale/:locale)/products(/:id)", to: "notes#catalog", as: :catalog
  get "/freshness", to: "notes#freshness"
end
