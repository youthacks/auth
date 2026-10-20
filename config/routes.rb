Rails.application.routes.draw do
  use_doorkeeper
  use_doorkeeper_openid_connect

  # Compatibility alias for clients that hardcoded the old frontend's JWKS path.
  get "oauth/jwks", to: "doorkeeper/openid_connect/discovery#keys"

  root "home#show"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  get  "login",  to: "sessions#new"
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  post "logout", to: "sessions#destroy"

  get  "signup", to: "registrations#new"
  post "signup", to: "registrations#create"

  get  "verify", to: "email_verifications#new"
  post "verify", to: "email_verifications#create"
  post "verify/resend", to: "email_verifications#resend", as: :resend_verification

  get "dashboard", to: "dashboard#show"

  # Catch-all for undefined routes
  match "*path", to: "errors#not_found", via: :all
end
