require "base64"

class OauthController < ApplicationController
  OAUTH_AUTHORIZE_PARAM_KEYS = %w[
    client_id
    redirect_uri
    response_type
    scope
    state
    nonce
    prompt
    response_mode
  ].freeze

  def authorize_validate
    rejection = reject_non_confidential_client
    return if rejection

    oauth_params = params.permit(*OAUTH_AUTHORIZE_PARAM_KEYS).to_h
    perform_authorize(oauth_params)
  end

  def authorize
    rejection = reject_non_confidential_client
    return if rejection

    oauth_params = oauth_request_params
    perform_authorize(oauth_params)
  end

  def consent
    render_error("Consent endpoint is not yet implemented", status: :not_implemented)
  end

  def jwks
    upstream_status, _upstream_headers, upstream_body = proxy_to_path("/oauth/discovery/keys", method: "GET")

    begin
      payload = JSON.parse(read_rack_body(upstream_body))
      render json: payload, status: upstream_status
    rescue JSON::ParserError
      render_error("Invalid JWKS response", status: :bad_gateway)
    end
  end

  def token
    rejection = reject_non_confidential_client
    return if rejection

    upstream_status, _upstream_headers, upstream_body = proxy_to_doorkeeper_token_endpoint(token_request_params)

    begin
      payload = JSON.parse(read_rack_body(upstream_body))
      render json: payload, status: upstream_status
    rescue JSON::ParserError
      render_error("Invalid token response", status: :bad_gateway)
    end
  end

  def userinfo
    method = request.request_method
    body = nil
    content_type = nil

    if method == "POST"
      body = request.raw_post.presence
      content_type = request.content_type.presence || "application/json"
    end

    upstream_status, upstream_headers, upstream_body = proxy_to_path(
      "/oauth/userinfo",
      method: method,
      input: body,
      content_type: content_type
    )

    response_headers = {}
    upstream_content_type = response_header_value(upstream_headers, "content-type")
    response_headers["Content-Type"] = upstream_content_type if upstream_content_type.present?

    render plain: read_rack_body(upstream_body), status: upstream_status, headers: response_headers
  end

  private

  def perform_authorize(oauth_params)
    if prompt_forced_reauthentication?(oauth_params)
      clear_access_token_cookie
      return render json: { requires_login: true, reason: "prompt_login" }, status: :unauthorized
    end

    if current_idp_user.nil?
      return render json: { requires_login: true }, status: :unauthorized
    end

    upstream_status, upstream_headers, upstream_body = proxy_to_doorkeeper_authorize_endpoint(oauth_params)
    location = response_location(upstream_headers)

    if location.present?
      return render json: { requires_login: false, redirect_url: location }
    end

    begin
      payload = JSON.parse(read_rack_body(upstream_body))

      if payload.is_a?(Hash)
        if payload["error"].to_s == "authentication_required"
          return render json: { requires_login: true }, status: :unauthorized
        end

        redirect_url = payload["redirect_url"].presence || payload["redirect_uri"].presence || payload["location"].presence
        if redirect_url.present?
          return render json: { requires_login: false, redirect_url: redirect_url }, status: :ok
        end
      end

      render json: payload, status: upstream_status
    rescue JSON::ParserError
      render_error("Authorization failed", status: :bad_gateway)
    end
  end

  def proxy_to_doorkeeper_authorize_endpoint(params_hash)
    query = URI.encode_www_form(params_hash)
    path = "/oauth/authorize"
    path = "#{path}?#{query}" if query.present?

    proxy_to_path(path, method: "GET")
  end

  def proxy_to_path(path, method: "GET", input: nil, content_type: nil)
    env_options = {
      method: method,
      "HTTP_ACCEPT" => "application/json",
      "HTTP_HOST" => request.host_with_port,
      "rack.url_scheme" => request.protocol.delete_suffix("://")
    }

    env_options[:input] = input if input
    env_options["CONTENT_TYPE"] = content_type if content_type

    env = Rack::MockRequest.env_for(
      path,
      env_options
    )

    token = bearer_token || oauth_handoff_token || cookie_token
    env["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token.present?

    Rails.application.call(env)
  end

  def proxy_to_doorkeeper_token_endpoint(params_hash)
    body = URI.encode_www_form(params_hash)

    proxy_to_path(
      "/oauth/token",
      method: "POST",
      input: body,
      content_type: "application/x-www-form-urlencoded"
    )
  end

  def oauth_request_params
    params.to_unsafe_h.slice(*OAUTH_AUTHORIZE_PARAM_KEYS)
  end

  def token_request_params
    params.to_unsafe_h.except("controller", "action", "format", "code_verifier")
  end

  def response_location(headers)
    return nil if headers.blank?

    headers.each do |key, value|
      return value if key.to_s.casecmp("location").zero?
    end

    nil
  end

  def response_header_value(headers, header_name)
    return nil if headers.blank?

    headers.each do |key, value|
      return value if key.to_s.casecmp(header_name).zero?
    end

    nil
  end

  def read_rack_body(body)
    chunks = []
    body.each { |part| chunks << part.to_s }
    chunks.join
  ensure
    body.close if body.respond_to?(:close)
  end

  def prompt_forced_reauthentication?(oauth_params)
    oauth_params["prompt"].to_s.split.include?("login")
  end

  def reject_non_confidential_client
    client_id = oauth_client_id
    return false if client_id.blank?

    client = Doorkeeper::Application.find_by(uid: client_id)
    return false if client.nil?
    return false if client.confidential?

    render json: {
      error: "unauthorized_client",
      error_description: "Only confidential clients are supported"
    }, status: :unauthorized
    true
  end

  def oauth_client_id
    params[:client_id].to_s.presence || basic_auth_client_id
  end

  def basic_auth_client_id
    auth_header = request.authorization.to_s
    return nil unless auth_header.start_with?("Basic ")

    encoded = auth_header.split(" ", 2)[1].to_s
    decoded = Base64.decode64(encoded)
    decoded.split(":", 2)[0].to_s.presence
  rescue ArgumentError
    nil
  end
end
