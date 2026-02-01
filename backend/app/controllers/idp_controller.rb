class IdpController < ApplicationController
  include SamlIdp::Controller

  def metadata
    render xml: SamlIdp.metadata.signed
  end

  def sso
    request_object = decode_request(params[:SAMLRequest], params[:Signature], params[:SigAlg], params[:RelayState])
    signed_request = params[:Signature].present?

    unless request_object&.valid?
      return render json: { error: "Invalid SAMLRequest" }, status: :unauthorized
    end

    relay_state = params[:RelayState].to_s

    if relay_state.present? && !allowed_relay_state?(relay_state)
      return render json: { error: "RelayState domain is not allowed" }, status: :unauthorized
    end

    acs_url = request_object.acs_url

    if acs_url.present? && !allowed_relay_state?(acs_url)
      return render json: { error: "ACS domain is not allowed" }, status: :unauthorized
    end

    user = current_idp_user

    if user.nil?
      return redirect_to frontend_login_url(request.fullpath)
    end

    issuer = request_object.issuer.to_s
    consent = user.saml_consents.find_by(issuer: issuer)

    if consent
      consent.update!(last_used_at: Time.current)
    elsif params[:consent].to_s == "true"
      user.saml_consents.create!(issuer: issuer, granted_at: Time.current, last_used_at: Time.current)
    else
      return redirect_to frontend_consent_url(request.fullpath, request_object, signed_request)
    end

    saml_response = encode_response(user.email, audience_uri: request_object.issuer)

    render html: saml_post_form(acs_url, saml_response, relay_state), status: :ok
  end

  private

  def allowed_relay_state?(url)
    uri = URI.parse(url)
    host = uri.host.to_s.downcase
    allowed_domains = Rails.configuration.x.allowed_domains || []
    allowed_domains.include?(host)
  rescue URI::InvalidURIError
    false
  end

  def frontend_login_url(return_to)
    frontend_base = ENV.fetch("FRONTEND_URL", "https://auth.youthacks.org")
    uri = URI.parse(frontend_base)
    query = URI.decode_www_form(String(uri.query))
    query << ["return_to", return_to]
    uri.query = URI.encode_www_form(query)
    uri.to_s
  end

  def frontend_consent_url(return_to, request_object, signed_request)
    frontend_base = ENV.fetch("FRONTEND_URL", "https://auth.youthacks.org")
    uri = URI.parse(frontend_base)
    uri.path = "/sso/consent"
    query = URI.decode_www_form(String(uri.query))
    query << ["return_to", return_to]
    query << ["issuer", request_object.issuer.to_s]
    query << ["acs", request_object.acs_url.to_s]
    query << ["trusted", signed_request ? "true" : "false"]
    uri.query = URI.encode_www_form(query)
    uri.to_s
  end

  def saml_post_form(acs_url, saml_response, relay_state)
    <<~HTML
      <html>
        <body onload="document.forms[0].submit()">
          <form method="post" action="#{ERB::Util.html_escape(acs_url)}">
            <input type="hidden" name="SAMLResponse" value="#{ERB::Util.html_escape(saml_response)}" />
            #{relay_state.present? ? "<input type=\"hidden\" name=\"RelayState\" value=\"#{ERB::Util.html_escape(relay_state)}\" />" : ""}
            <noscript>
              <button type="submit">Continue</button>
            </noscript>
          </form>
        </body>
      </html>
    HTML
  end
end
