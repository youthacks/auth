SamlIdp.configure do |config|
  base = ENV.fetch("BACKEND_URL", "https://auth.youthacks.org")

  config.x509_certificate = ENV["SAML_IDP_CERT"].presence || SamlIdp::Default::X509_CERTIFICATE
  config.secret_key = ENV["SAML_IDP_PRIVATE_KEY"].presence || SamlIdp::Default::SECRET_KEY
  config.algorithm = :sha256

  config.organization_name = "Youthacks"
  config.organization_url = base
  config.base_saml_location = "#{base}/v1/idp"
  config.single_service_post_location = "#{base}/v1/idp/sso"

  config.name_id.formats = {
    email_address: ->(principal) { principal.email }
  }

  config.attributes = {
    GivenName: { getter: :first_name },
    SurName: { getter: :last_name },
    EmailAddress: { getter: :email },
    Username: { getter: :username }
  }
end
