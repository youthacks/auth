# frozen_string_literal: true

Doorkeeper.configure do
  orm :active_record

  # This block is executed in the context of Doorkeeper's controllers, which
  # inherit from ApplicationController, so the session helpers are available.
  resource_owner_authenticator do
    current_user || redirect_to(login_path(return_to: request.fullpath))
  end

  # Only admins may manage OAuth clients via Doorkeeper's own applications controller.
  admin_authenticator do
    unless current_user&.admin?
      redirect_to root_path
    end
  end

  base_controller "ApplicationController"

  access_token_expires_in 15.minutes
  use_refresh_token

  default_scopes :openid, :profile, :email

  grant_flows %w[authorization_code client_credentials]

  # All registered clients are first-party; no consent screen.
  skip_authorization do |_resource_owner, _client|
    true
  end

  force_ssl_in_redirect_uri { |uri| !%w[localhost 127.0.0.1].include?(uri.host) && !Rails.env.development? }
end

# Only confidential clients may use the authorization and token endpoints.
Rails.application.config.to_prepare do
  Doorkeeper::AuthorizationsController.include(Oauth::ConfidentialClientsOnly)
  Doorkeeper::TokensController.include(Oauth::ConfidentialClientsOnly)
end
