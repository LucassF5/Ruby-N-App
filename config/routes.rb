Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  resource :session
  resources :passwords, param: :token
  resources :registrations, only: %i[ new create ]
  match "/auth/apple/callback", to: "omniauth#apple", via: [:get, :post]
  get "/auth/failure", to: "omniauth#failure"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "profile" => "pages#profile"
  resource :settings, only: %i[ edit update ]

  resources :categories, except: [:show]
  resources :shifts, except: [:show]

  get "calendar", to: "calendar#show", as: :calendar
  get "calendar/:date", to: "calendar#day", as: :calendar_day, constraints: { date: /\d{4}-\d{2}-\d{2}/ }

  # Defines the root path route ("/")
  root "shifts#index"
end
