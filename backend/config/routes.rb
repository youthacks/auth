Rails.application.routes.draw do
  use_doorkeeper
  use_doorkeeper_openid_connect
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root to: "welcome#show"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  scope "v1", defaults: { format: :json } do
    get "oauth/authorize", to: "oauth#authorize"
    post "oauth/token", to: "oauth#token"

    scope "oidc" do
      post "authorize/validate", to: "oauth#authorize_validate"
      post "login", to: "auth#login"
      post "consent", to: "oauth#consent"
      post "token", to: "oauth#token"
      get "userinfo", to: "users#show"
      get "jwks", to: "oauth#jwks"
    end

    post "auth/signup", to: "auth#signup"
    post "auth/login", to: "auth#login"
    post "auth/refresh", to: "auth#refresh"
    post "auth/logout", to: "auth#logout"
    post "auth/forgot_password", to: "auth#forgot_password"
    post "auth/resend_email_verification", to: "auth#resend_email_verification"
    post "auth/verify_email", to: "auth#verify_email"
    get "auth/me", to: "users#show"

    get "user", to: "users#show"

    namespace :admin do
      resources :clients, only: [:index, :show, :create, :update, :destroy]
    end
  end

  # Catch-all for undefined routes
  match "*path", to: "errors#not_found", via: :all
end
