ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end

class ActionDispatch::IntegrationTest
  def sign_in_as(user, password: "password123")
    post login_path, params: { identifier: user.email, password: password }
    assert_response :redirect
  end

  def create_client(name: "Test App", redirect_uri: "https://client.example.com/callback", confidential: true)
    Doorkeeper::Application.create!(
      name: name,
      redirect_uri: redirect_uri,
      scopes: "openid profile email",
      confidential: confidential
    )
  end
end
