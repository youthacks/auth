require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "home page renders and links to sign in" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", login_path
    assert_select "a[href=?]", signup_path
  end

  test "signup sends a verification code, verifying it creates the account and allows login" do
    get signup_path
    assert_response :success

    assert_emails 1 do
      post signup_path, params: { user: {
        first_name: "Bob", last_name: "Builder", username: "Bob", email: "Bob@Example.com",
        password: "secret-pass", password_confirmation: "secret-pass"
      } }
    end
    assert_redirected_to verify_path(email: "bob@example.com")
    assert_nil User.find_by(email: "bob@example.com"), "user must not exist before verification"

    code = ActionMailer::Base.deliveries.last.subject[/\d{6}/]
    assert code

    follow_redirect!
    assert_response :success
    assert_select "input[name=email][readonly]"

    post verify_path, params: { email: "bob@example.com", code: "000000" }
    assert_response :unprocessable_entity
    assert_match "Invalid or expired code", response.body

    post verify_path, params: { email: "bob@example.com", code: code }
    assert_redirected_to login_path(identifier: "bob@example.com")

    user = User.find_by(email: "bob@example.com")
    assert user
    assert_equal "bob", user.username

    post login_path, params: { identifier: "bob", password: "secret-pass" }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_select "h1", "Dashboard"
    assert_match "Bob Builder", response.body
  end

  test "signup with invalid data re-renders the form with errors" do
    assert_no_emails do
      post signup_path, params: { user: { first_name: "", last_name: "", username: "x", email: "bad", password: "a", password_confirmation: "b" } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert] li", minimum: 2
  end

  test "signup with an existing email is rejected" do
    post signup_path, params: { user: {
      first_name: "A", last_name: "B", username: "newname", email: users(:alice).email,
      password: "secret-pass", password_confirmation: "secret-pass"
    } }
    assert_response :unprocessable_entity
    assert_match "Email has already been taken", response.body
  end

  test "resend issues a new code for a pending signup" do
    post signup_path, params: { user: {
      first_name: "Cy", last_name: "Clist", username: "cy", email: "cy@example.com",
      password: "secret-pass", password_confirmation: "secret-pass"
    } }
    # The minimum send interval is enforced; simulate time passing.
    EmailVerification.where(email: "cy@example.com").update_all(last_sent_at: 2.minutes.ago)

    assert_emails 1 do
      post resend_verification_path, params: { email: "cy@example.com" }
    end
    assert_redirected_to verify_path(email: "cy@example.com")
  end

  test "resend is rate limited within the minimum interval" do
    post signup_path, params: { user: {
      first_name: "Cy", last_name: "Clist", username: "cy2", email: "cy2@example.com",
      password: "secret-pass", password_confirmation: "secret-pass"
    } }
    assert_no_emails do
      post resend_verification_path, params: { email: "cy2@example.com" }
    end
    assert_response :unprocessable_entity
    assert_match "Too many verification requests", response.body
  end

  test "verify page without an email explains what to do" do
    get verify_path
    assert_response :success
    assert_match "Missing signup email", response.body
    assert_select "input[name=code][disabled]"
  end

  test "login with wrong password fails and locks the account after repeated attempts" do
    alice = users(:alice)

    post login_path, params: { identifier: alice.email, password: "nope" }
    assert_response :unprocessable_entity
    assert_match "Invalid email/username or password", response.body

    (User::LOCKOUT_THRESHOLD - 1).times do
      post login_path, params: { identifier: alice.email, password: "nope" }
    end
    assert alice.reload.locked?

    post login_path, params: { identifier: alice.email, password: "password123" }
    assert_response :unprocessable_entity
    assert_match "Account locked", response.body

    alice.update!(locked_at: User::LOCKOUT_DURATION.ago - 1.minute)
    post login_path, params: { identifier: alice.email, password: "password123" }
    assert_redirected_to dashboard_path
    assert_equal 0, alice.reload.failed_login_attempts
  end

  test "login by username works and sets a session cookie" do
    post login_path, params: { identifier: "ALICE", password: "password123" }
    assert_redirected_to dashboard_path
    assert cookies[:idp_access_token].present?
    assert_equal 1, users(:alice).access_tokens.active.count
  end

  test "login redirects to a safe return_to and ignores external ones" do
    post login_path, params: { identifier: "alice", password: "password123", return_to: "/oauth/authorize?client_id=x" }
    assert_redirected_to "/oauth/authorize?client_id=x"

    delete logout_path

    post login_path, params: { identifier: "alice", password: "password123", return_to: "https://evil.example.com/" }
    assert_redirected_to dashboard_path
  end

  test "signed in users visiting login are sent on, unless reauthentication is requested" do
    sign_in_as users(:alice)

    get login_path
    assert_redirected_to dashboard_path

    get login_path(prompt: "login", return_to: "/dashboard")
    assert_response :success
    assert_match "Please sign in again", response.body
    assert_equal 0, users(:alice).access_tokens.active.count, "prompt=login revokes the current session"
  end

  test "dashboard requires sign in and logout revokes the token" do
    get dashboard_path
    assert_redirected_to login_path(return_to: "/dashboard")

    sign_in_as users(:alice)
    get dashboard_path
    assert_response :success

    delete logout_path
    assert_redirected_to login_path
    assert_equal 0, users(:alice).access_tokens.active.count

    get dashboard_path
    assert_response :redirect
  end

  test "unknown paths render the 404 page" do
    get "/does/not/exist"
    assert_response :not_found
    assert_select "h1", "Page not found"
  end
end
