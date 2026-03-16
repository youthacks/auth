Rails.application.routes.draw do
  use_doorkeeper
  use_doorkeeper_openid_connect
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root to: "welcome#show"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  scope "v1" do

    scope "oauth" do
      get "authorize", to: "oauth#authorize"
      post "token", to: "oauth#token"
    end

    scope "oidc" do
      post "authorize/validate", to: "oauth#authorize_validate"
      post "login", to: "auth#login"
      post "consent", to: "oauth#consent"
      post "token", to: "oauth#token"
      get "userinfo", to: "oauth#userinfo"
      post "userinfo", to: "oauth#userinfo"
      get "jwks", to: "oauth#jwks"
    end

    scope "auth" do

      post "signup", to: "auth#signup"
      post "login", to: "auth#login"
      post "refresh", to: "auth#refresh"
      post "logout", to: "auth#logout"
      post "forgot_password", to: "auth#forgot_password"
      post "resend_email_verification", to: "auth#resend_email_verification"
      post "verify_email", to: "auth#verify_email"
      get "me", to: "users#show"
    end

    get "user", to: "users#show"

    namespace :admin do
      resources :clients, only: [:index, :show, :create, :update, :destroy]
    end
  end

  # Catch-all for undefined routes
  match "*path", to: "errors#not_found", via: :all
end
