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

    @refresh_token = RefreshToken.issue_for(user, request)
    idp_session = issue_idp_session(user)

    cookies.encrypted[:idp_session] = {
      value: idp_session,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?,
      expires: 1.day.from_now
    }

    @user = user
    @message = "Login successful"
    # Renders app/views/auth/login.json.jbuilder
  end

  def logout
    raw_token = params[:refresh_token].to_s

    if raw_token.blank?
      @error = "refresh_token is required"
      return render "shared/error", status: :unprocessable_entity
    end

    record = RefreshToken.active.find_by(token_digest: RefreshToken.digest(raw_token))

    if record.nil?
      @error = "Invalid or expired refresh token"
      return render "shared/error", status: :unauthorized
    end

    record.revoke!

    cookies.delete(:idp_session)

    @message = "Logged out"
    # Renders app/views/auth/logout.json.jbuilder
  end

  private

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
