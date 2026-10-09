require "test_helper"

class OidcFlowTest < ActionDispatch::IntegrationTest
  setup do
    @client = create_client
    @redirect_uri = @client.redirect_uri
  end

  def authorize_params(extra = {})
    {
      client_id: @client.uid,
      redirect_uri: @redirect_uri,
      response_type: "code",
      scope: "openid profile email",
      state: "xyz",
      nonce: "n-0S6_WzA2Mj"
    }.merge(extra)
  end

  test "discovery document and JWKS are served from this app" do
    get "/.well-known/openid-configuration"
    assert_response :success
    doc = response.parsed_body
    assert_equal Rails.configuration.x.app_url, doc["issuer"]
    assert_equal "http://www.example.com/oauth/authorize", doc["authorization_endpoint"]
    assert_equal "http://www.example.com/oauth/token", doc["token_endpoint"]
    assert_equal "http://www.example.com/oauth/userinfo", doc["userinfo_endpoint"]
    assert_equal "http://www.example.com/oauth/discovery/keys", doc["jwks_uri"]

    get "/oauth/discovery/keys"
    assert_response :success
    assert_equal "RS256", response.parsed_body["keys"].first["alg"]

    get "/oauth/jwks"
    assert_response :success
  end

  test "authorize redirects anonymous users to login and back" do
    get oauth_authorization_path(authorize_params)
    assert_response :redirect
    location = URI.parse(response.location)
    assert_equal "/login", location.path
    return_to = Rack::Utils.parse_query(location.query)["return_to"]
    assert return_to.start_with?("/oauth/authorize?")

    post login_path, params: { identifier: "alice", password: "password123", return_to: return_to }
    assert_redirected_to return_to

    follow_redirect!
    assert_response :redirect
    assert response.location.start_with?(@redirect_uri)
  end

  test "full authorization code flow issues an id_token and userinfo" do
    sign_in_as users(:alice)

    get oauth_authorization_path(authorize_params)
    assert_response :redirect
    callback = URI.parse(response.location)
    assert_equal "client.example.com", callback.host
    query = Rack::Utils.parse_query(callback.query)
    assert_equal "xyz", query["state"]
    code = query["code"]
    assert code.present?

    # Token exchange with a JSON body, as documented in OAUTH_FLOW.md.
    post "/oauth/token", params: {
      grant_type: "authorization_code",
      code: code,
      client_id: @client.uid,
      client_secret: @client.secret,
      redirect_uri: @redirect_uri
    }, as: :json
    assert_response :success
    tokens = response.parsed_body
    assert tokens["access_token"].present?
    assert tokens["refresh_token"].present?
    assert tokens["id_token"].present?

    get "/oauth/discovery/keys"
    jwks = response.parsed_body
    claims, header = JWT.decode(tokens["id_token"], nil, true, algorithms: [ "RS256" ], jwks: jwks)
    assert_equal "RS256", header["alg"]
    assert_equal Rails.configuration.x.app_url, claims["iss"]
    assert_equal users(:alice).id.to_s, claims["sub"]
    assert_equal @client.uid, claims["aud"]
    assert_equal "n-0S6_WzA2Mj", claims["nonce"]
    assert_equal "alice@example.com", claims["email"]
    assert_equal "Alice Example", claims["name"]
    assert_equal "alice", claims["username"]

    get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{tokens["access_token"]}" }
    assert_response :success
    info = response.parsed_body
    assert_equal users(:alice).id.to_s, info["sub"]
    assert_equal "Alice", info["given_name"]
    assert_equal "Example", info["family_name"]
    assert_equal "alice@example.com", info["email"]

    # Refresh token grant
    post "/oauth/token", params: {
      grant_type: "refresh_token",
      refresh_token: tokens["refresh_token"],
      client_id: @client.uid,
      client_secret: @client.secret
    }, as: :json
    assert_response :success
    assert response.parsed_body["access_token"].present?
    assert_not_equal tokens["access_token"], response.parsed_body["access_token"]
  end

  test "token endpoint rejects a wrong client secret" do
    post "/oauth/token", params: {
      grant_type: "authorization_code", code: "bogus", client_id: @client.uid,
      client_secret: "wrong", redirect_uri: @redirect_uri
    }, as: :json
    assert_response :unauthorized
    assert_equal "invalid_client", response.parsed_body["error"]
  end

  test "prompt=login forces reauthentication and strips the prompt from the return URL" do
    sign_in_as users(:alice)

    get oauth_authorization_path(authorize_params(prompt: "login"))
    assert_response :redirect
    location = URI.parse(response.location)
    assert_equal "/login", location.path
    params = Rack::Utils.parse_query(location.query)
    assert_equal "login", params["prompt"]
    assert_no_match(/prompt/, params["return_to"])
    assert_equal 0, users(:alice).access_tokens.active.count, "existing session is revoked"

    # Signing in again completes the flow.
    post login_path, params: { identifier: "alice", password: "password123", return_to: params["return_to"], prompt: "login" }
    assert_redirected_to params["return_to"]
    follow_redirect!
    assert_response :redirect
    assert response.location.start_with?(@redirect_uri)
  end

  test "public (non-confidential) clients are rejected" do
    public_client = create_client(name: "Public", confidential: false)
    sign_in_as users(:alice)

    get oauth_authorization_path(authorize_params(client_id: public_client.uid))
    assert_response :unauthorized
    assert_equal "unauthorized_client", response.parsed_body["error"]

    post "/oauth/token", params: { grant_type: "client_credentials", client_id: public_client.uid, client_secret: public_client.secret }, as: :json
    assert_response :unauthorized
    assert_equal "unauthorized_client", response.parsed_body["error"]
  end

  test "mismatched redirect_uri is an error, not a redirect" do
    sign_in_as users(:alice)
    get oauth_authorization_path(authorize_params(redirect_uri: "https://attacker.example.com/cb"))
    assert_response :bad_request
    assert_match "redirect uri", response.body.downcase
  end
end
