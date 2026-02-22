
class AuthController < ApplicationController
  def signup
    user = User.new(signup_params)

    unless user.valid?
      @errors = user.errors.full_messages
      return render "shared/error", status: :unprocessable_entity
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
      @error = "Too many verification requests, try again later"
      return render "shared/error", status: :too_many_requests
    end

    @message = "Verification code sent"
    render status: :created
    # Renders app/views/auth/signup.json.jbuilder
  end

  def resend_email_verification
    email = params[:email].to_s

    if email.blank?
      @error = "Email is required"
      return render "shared/error", status: :unprocessable_entity
    end

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      @error = "Invalid email format"
      return render "shared/error", status: :unprocessable_entity
    end

    if User.exists?(email: email.strip.downcase)
      @error = "Account already verified"
      return render "shared/error", status: :unprocessable_entity
    end

    pending = EmailVerification.latest_for(email)

    if pending.nil?
      @error = "No pending signup"
      return render "shared/error", status: :not_found
    end

    result = EmailVerification.issue_for(email, pending.payload)

    if result == :rate_limited
      @error = "Too many verification requests, try again later"
      return render "shared/error", status: :too_many_requests
    end
    
    @message = "Verification code sent"
    # Renders app/views/auth/resend_email_verification.json.jbuilder
  end

  def verify_email
    email = params[:email].to_s
    code = params[:email_code].to_s

    if email.blank? || code.blank?
      @error = "Email and email_code are required"
      return render "shared/error", status: :unprocessable_entity
    end

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      @error = "Invalid email format"
      return render "shared/error", status: :unprocessable_entity
    end

    pending = EmailVerification.active.find_by(email: email.strip.downcase)

    if pending.nil?
      @error = "Invalid or expired code"
      return render "shared/error", status: :unprocessable_entity
    end

    result = EmailVerification.consume!(email, code)

    if result == :too_many
      @error = "Too many attempts, request a new code"
      return render "shared/error", status: :too_many_requests
    end

    if result != :ok
      @error = "Invalid or expired code"
      return render "shared/error", status: :unprocessable_entity
    end

    user = User.new(pending.payload)

    if user.save
      @user = user
      @message = "Account created"
      render status: :created
      # Renders app/views/auth/verify_email.json.jbuilder
    else
      @errors = user.errors.full_messages
      render "shared/errors", status: :unprocessable_entity
    end
  end

  def forgot_password
    identifier = params[:identifier].presence || params[:email].to_s

    if identifier.blank?
      @error = "Email or username is required"
      render "shared/error", status: :unprocessable_entity
    else
      @error = "Forgot password is available only in development"
      render "shared/error", status: :not_implemented
    end
  end

  def login
    identifier = params[:identifier].presence || params[:email].to_s
    password = params[:password].to_s

    if identifier.blank? || password.blank?
      @error = "Email or username and password are required"
      return render "shared/error", status: :unprocessable_entity
    end

    normalized_email = identifier.strip.downcase
    user = if normalized_email.match?(URI::MailTo::EMAIL_REGEXP)
      User.find_by(email: normalized_email)
    else
      User.find_by(username: normalized_email)
    end

    user&.unlock_if_expired!

    if user&.locked?
      @error = "Account locked due to too many failed attempts"
      return render "shared/error", status: :locked
    end

    if user.nil? || !user.authenticate(password)
      user&.register_failed_login!
      @error = "Invalid email/username or password"
      return render "shared/error", status: :unauthorized
    end

    user.reset_failed_logins!
    user.update!(last_login_at: Time.current)

    access_token = AccessToken.issue_for(user, request)
    @user = user
    @access_token = access_token
    @message = "Login successful"
    # Renders app/views/auth/login.json.jbuilder
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
  end

  def user
    @user = current_idp_user
    unless @user
      @error = "User not found or not authenticated"
      render "shared/error", formats: :json, status: :unauthorized
      return
    end
    Rails.logger.info("Authenticated user: #{@user.username} (ID: #{@user.id})")
    render "auth/user", formats: :json, status: :ok
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

  def current_idp_user
    auth_header = request.headers["Authorization"].to_s
    return nil unless auth_header.start_with?("Bearer ")
    raw_token = auth_header.split(" ", 2)[1]
    return nil if raw_token.blank?

    digest = AccessToken.digest(raw_token)
    token_record = AccessToken.active.find_by(token_digest: digest)
    return nil unless token_record && !token_record.expired?

    token_record.update!(last_used_at: Time.current)
    token_record.user
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
