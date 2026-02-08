Rails.application.routes.draw do
  use_doorkeeper
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root to: "welcome#show"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  scope "v1" do
    post "auth/signup", to: "auth#signup"
    post "auth/login", to: "auth#login"
    post "auth/logout", to: "auth#logout"
    post "auth/forgot_password", to: "auth#forgot_password"
    post "auth/resend_email_verification", to: "auth#resend_email_verification"
    post "auth/verify_email", to: "auth#verify_email"

    get "idp/metadata", to: "idp#metadata"
    match "idp/sso", to: "idp#sso", via: [:get, :post]
  end

  # Catch-all for undefined routes
  match "*path", to: "errors#not_found", via: :all
end
