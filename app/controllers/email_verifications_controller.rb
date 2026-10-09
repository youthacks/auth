class EmailVerificationsController < ApplicationController
  rate_limit to: 10, within: 10.minutes, only: [ :create, :resend ],
    with: -> { redirect_to verify_path(email: params[:email]), alert: "Too many attempts. Try again later." }

  before_action :load_email

  def new
    if @email.blank?
      flash.now[:alert] = "Missing signup email. Please start again from sign up."
    end
  end

  def create
    code = params[:code].to_s.strip

    if @email.blank? || code.blank?
      return fail_verification("Email and verification code are required.")
    end

    pending = EmailVerification.active.find_by(email: @email)
    return fail_verification("Invalid or expired code.") if pending.nil?

    case EmailVerification.consume!(@email, code)
    when :too_many
      return fail_verification("Too many attempts. Request a new code.")
    when :ok
      # continue
    else
      return fail_verification("Invalid or expired code.")
    end

    user = User.new(pending.payload)
    if user.save
      redirect_to login_path(identifier: user.email), notice: "Email verified! You can now sign in."
    else
      fail_verification("Could not create account: #{user.errors.full_messages.to_sentence}")
    end
  end

  def resend
    return fail_verification("Email is required.") if @email.blank?
    return fail_verification("Invalid email format.") unless @email.match?(URI::MailTo::EMAIL_REGEXP)

    if User.exists?(email: @email)
      return redirect_to login_path(identifier: @email), notice: "That account is already verified. Please sign in."
    end

    pending = EmailVerification.latest_for(@email)
    return redirect_to signup_path, alert: "No pending signup for that email. Please sign up again." if pending.nil?

    if EmailVerification.issue_for(@email, pending.payload) == :rate_limited
      return fail_verification("Too many verification requests. Try again in a minute.")
    end

    redirect_to verify_path(email: @email), notice: "A new verification code has been sent."
  end

  private

  def load_email
    @email = EmailVerification.normalize_email(params[:email])
  end

  def fail_verification(message)
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end
end
