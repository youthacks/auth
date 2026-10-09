class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to login_path(return_to: params[:return_to]), alert: "Too many sign-in attempts. Try again later." }

  def new
    @return_to = safe_return_to(params[:return_to])
    @reauthenticate = params[:prompt].to_s.split.include?("login")
    @identifier = params[:identifier].to_s

    if @reauthenticate
      # OIDC prompt=login: drop the existing session and ask for credentials again.
      sign_out if signed_in?
      flash.now[:notice] = "Please sign in again to continue."
    elsif signed_in?
      redirect_to(@return_to || dashboard_path)
    elsif params[:return_to].present? && @return_to.nil?
      flash.now[:alert] = "Invalid return destination."
    end
  end

  def create
    @return_to = safe_return_to(params[:return_to])
    @identifier = params[:identifier].to_s.strip
    password = params[:password].to_s

    if @identifier.blank? || password.blank?
      return fail_login("Email or username and password are required.")
    end

    user = User.find_by_identifier(@identifier)
    user&.unlock_if_expired!

    if user&.locked?
      return fail_login("Account locked due to too many failed attempts. Try again in #{User::LOCKOUT_DURATION.inspect}.")
    end

    if user.nil? || !user.authenticate(password)
      user&.register_failed_login!
      return fail_login("Invalid email/username or password.")
    end

    user.reset_failed_logins!
    sign_in(user)
    redirect_to(@return_to || dashboard_path, notice: "Welcome back, #{user.display_name}!")
  end

  def destroy
    sign_out
    redirect_to login_path, notice: "You have been signed out."
  end

  private

  def fail_login(message)
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end
end
