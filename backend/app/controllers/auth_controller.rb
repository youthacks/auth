
class AuthController < ApplicationController
  def signup
    user = User.new(signup_params)

    unless user.valid?
      return render_error("Validation failed", status: :unprocessable_entity, errors: user.errors.full_messages)
    end

    payload = user.attributes.slice(
      "first_name",
      "last_name",
      "preferred_name",
      "username",
      "email",
      "password_digest"
    )

    result = EmailVerification.issue_for(user.email, payload)

    if result == :rate_limited
      return render_error("Too many verification requests, try again later", status: :too_many_requests)
    end

    @message = "Verification code sent"
    render :signup, status: :created
  end

  def resend_email_verification
    email = params[:email].to_s

    if email.blank?
      return render_error("Email is required", status: :unprocessable_entity)
    end

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      return render_error("Invalid email format", status: :unprocessable_entity)
    end

    if User.exists?(email: email.strip.downcase)
      return render_error("Account already verified", status: :unprocessable_entity)
    end

    pending = EmailVerification.latest_for(email)

    if pending.nil?
      return render_error("No pending signup", status: :not_found)
    end

    result = EmailVerification.issue_for(email, pending.payload)

    if result == :rate_limited
      return render_error("Too many verification requests, try again later", status: :too_many_requests)
    end

    @message = "Verification code sent"
    render :resend_email_verification, status: :ok
  end

  def verify_email
    email = params[:email].to_s
    code = params[:email_code].to_s

    if email.blank? || code.blank?
      return render_error("Email and email_code are required", status: :unprocessable_entity)
    end

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      return render_error("Invalid email format", status: :unprocessable_entity)
    end

    pending = EmailVerification.active.find_by(email: email.strip.downcase)

    if pending.nil?
      return render_error("Invalid or expired code", status: :unprocessable_entity)
    end

    result = EmailVerification.consume!(email, code)

    if result == :too_many
      return render_error("Too many attempts, request a new code", status: :too_many_requests)
    end

    if result != :ok
      return render_error("Invalid or expired code", status: :unprocessable_entity)
    end

    user = User.new(pending.payload)

    if user.save
      @user = user
      @message = "Account created"
      render :verify_email, status: :created
    else
      render_error("Validation failed", status: :unprocessable_entity, errors: user.errors.full_messages)
    end
  end

  def forgot_password
    identifier = params[:identifier].presence || params[:email].to_s

    if identifier.blank?
      render_error("Email or username is required", status: :unprocessable_entity)
    else
      render_error("Forgot password is available only in development", status: :not_implemented)
    end
  end

  def login
    identifier = params[:identifier].presence || params[:email].to_s
    password = params[:password].to_s

    if identifier.blank? || password.blank?
      return render_error("Email or username and password are required", status: :unprocessable_entity)
    end

    normalized_email = identifier.strip.downcase
    user = if normalized_email.match?(URI::MailTo::EMAIL_REGEXP)
      User.find_by(email: normalized_email)
    else
      User.find_by(username: normalized_email)
    end

    user&.unlock_if_expired!

    if user&.locked?
      return render_error("Account locked due to too many failed attempts", status: :locked)
    end

    if user.nil? || !user.authenticate(password)
      user&.register_failed_login!
      return render_error("Invalid email/username or password", status: :unauthorized)
    end

    user.reset_failed_logins!
    user.update!(last_login_at: Time.current)

    @user = user
    @access_token = AccessToken.issue_for(user, request)
    @message = "Login successful"
    render :login, status: :ok
  end

  def logout
    # Revoke the current access token if present
    auth_header = request.headers["Authorization"].to_s
    if auth_header.start_with?("Bearer ")
      raw_token = auth_header.split(" ", 2)[1]
      digest = AccessToken.digest(raw_token)
      token_record = AccessToken.active.find_by(token_digest: digest)
      token_record&.revoke!
    end
    @message = "Logged out"
    render :logout, status: :ok
  end

  def refresh
    render_error("Refresh token flow is not implemented", status: :not_implemented)
  end

  def user
    user = current_idp_user
    return render_error("User not found or not authenticated", status: :unauthorized) unless user

    Rails.logger.info("Authenticated user: #{user.username} (ID: #{user.id})")
    @user = user
    render "auth/user", status: :ok
  end

  private

  def issue_idp_session(user)
    payload = {
      sub: user.id,
      exp: 1.month.from_now.to_i,
      iat: Time.current.to_i,
      type: "idp"
    }
    JWT.encode(payload, Rails.application.secret_key_base, "HS256")
  end

  def signup_params
    params.fetch(:user, params).permit(
      :first_name,
      :last_name,
      :preferred_name,
      :username,
      :email,
      :password,
      :password_confirmation
    )
  end

end
