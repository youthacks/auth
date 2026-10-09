# frozen_string_literal: true

Doorkeeper::OpenidConnect.configure do
  issuer do |_resource_owner, _application|
    Rails.configuration.x.app_url
  end

  signing_key Rails.application.credentials.dig(:doorkeeper, :oidc, :signing_key)

  subject_types_supported [ :public ]

  resource_owner_from_access_token do |access_token|
    User.find_by(id: access_token.resource_owner_id)
  end

  auth_time_from_resource_owner do |resource_owner|
    (resource_owner.last_login_at || resource_owner.created_at).to_i
  end

  # Called for `prompt=login` (and expired `max_age`). `return_to` is the
  # authorize URL with `prompt=login` already removed, so sending the user back
  # there after signing in completes the flow without looping.
  reauthenticate_resource_owner do |_resource_owner, return_to|
    sign_out
    redirect_to login_path(return_to: return_to, prompt: "login")
  end

  select_account_for_resource_owner do |_resource_owner, _return_to|
    true
  end

  subject do |resource_owner, _application|
    resource_owner.id.to_s
  end

  # Claims are returned both inside the ID token and from /oauth/userinfo,
  # gated by the `profile` and `email` scopes.
  claims do
    in_both = %i[id_token user_info]
    normal_claim(:name, response: in_both) { |resource_owner| resource_owner.full_name }
    normal_claim(:given_name, response: in_both) { |resource_owner| resource_owner.first_name }
    normal_claim(:family_name, response: in_both) { |resource_owner| resource_owner.last_name }
    normal_claim(:username, response: in_both, scope: :profile) { |resource_owner| resource_owner.username }
    normal_claim(:email, response: in_both) { |resource_owner| resource_owner.email }
  end
end
