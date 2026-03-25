# frozen_string_literal: true

Doorkeeper::OpenidConnect.configure do
  issuer do |resource_owner, application|
    ENV['FRONTEND_URL'].presence || Rails.application.credentials.dig(:url, :frontend) || ENV['BACKEND_URL'].presence || Rails.application.credentials.dig(:url, :backend)
  end

  signing_key OpenSSL::PKey::RSA.new(
    Rails.application.credentials.dig(:doorkeeper, :oidc, :signing_key)
  )

  subject_types_supported [:public]

  resource_owner_from_access_token do |access_token|
    User.find_by(id: access_token.resource_owner_id)
  end

  auth_time_from_resource_owner do |resource_owner|
    (resource_owner.last_login_at || resource_owner.created_at).to_i
  end

  reauthenticate_resource_owner do |resource_owner, return_to|
    false
  end

  # Depending on your configuration, a DoubleRenderError could be raised
  # if render/redirect_to is called at some point before this callback is executed.
  # To avoid the DoubleRenderError, you could add these two lines at the beginning
  #  of this callback: (Reference: https://github.com/rails/rails/issues/25106)
  #   self.response_body = nil
  #   @_response_body = nil
  select_account_for_resource_owner do |resource_owner, return_to|
    true
  end

  subject do |resource_owner, application|
    resource_owner.id.to_s
  end

  # Protocol to use when generating URIs for the discovery endpoint,
  # for example if you also use HTTPS in development
  # protocol do
  #   :https
  # end

  # Expiration time on or after which the ID Token MUST NOT be accepted for processing. (default 120 seconds).
  # expiration 600

  claims do
    normal_claim :name do |resource_owner|
      "#{resource_owner.first_name} #{resource_owner.last_name}".strip
    end

    normal_claim :given_name do |resource_owner|
      resource_owner.first_name
    end

    normal_claim :family_name do |resource_owner|
      resource_owner.last_name
    end

    normal_claim :username do |resource_owner|
      resource_owner.username
    end

    normal_claim :email do |resource_owner|
      resource_owner.email
    end
  end
end
