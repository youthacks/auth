require "test_helper"

class AdminClientsTest < ActionDispatch::IntegrationTest
  test "anonymous users are sent to login" do
    get admin_clients_path
    assert_redirected_to login_path(return_to: "/admin/clients")
  end

  test "non-admins are sent to the dashboard" do
    sign_in_as users(:alice)
    get admin_clients_path
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match "do not have access", response.body
  end

  test "admins can create, view, edit and delete clients; the secret is shown once" do
    sign_in_as users(:admin)

    get admin_clients_path
    assert_response :success
    assert_match "No applications yet", response.body

    assert_difference "Doorkeeper::Application.count", 1 do
      post admin_clients_path, params: { client: {
        name: "Scheduler",
        redirect_uri: "https://sched.example.com/callback\n\nhttps://sched.example.com/callback\nhttps://staging.sched.example.com/callback"
      } }
    end
    client = Doorkeeper::Application.last
    assert_redirected_to admin_client_path(client)
    assert client.confidential?
    assert_equal "openid profile email", client.scopes.to_s
    assert_equal [ "https://sched.example.com/callback", "https://staging.sched.example.com/callback" ], client.redirect_uri.split("\n")

    follow_redirect!
    assert_response :success
    assert_match client.secret, response.body
    assert_match "will not be shown again", response.body

    get admin_client_path(client)
    assert_no_match client.secret, response.body

    get edit_admin_client_path(client)
    assert_response :success

    patch admin_client_path(client), params: { client: { name: "Scheduler v2", redirect_uri: "https://sched.example.com/cb" } }
    assert_redirected_to admin_client_path(client)
    assert_equal "Scheduler v2", client.reload.name
    assert_equal "https://sched.example.com/cb", client.redirect_uri

    get admin_clients_path
    assert_match "Scheduler v2", response.body

    assert_difference "Doorkeeper::Application.count", -1 do
      delete admin_client_path(client)
    end
    assert_redirected_to admin_clients_path
  end

  test "invalid client data re-renders the form" do
    sign_in_as users(:admin)
    post admin_clients_path, params: { client: { name: "", redirect_uri: "not a url" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]"
  end
end
