class RegistrationsController < ApplicationController
  rate_limit to: 5, within: 10.minutes, only: :create,
    with: -> { redirect_to signup_path, alert: "Too many sign-up attempts. Try again later." }

  before_action :redirect_signed_in_users

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    unless @user.valid?
      return render :new, status: :unprocessable_entity
    end

    payload = @user.attributes.slice("first_name", "last_name", "preferred_name", "username", "email", "password_digest")
    result = EmailVerification.issue_for(@user.email, payload)

    if result == :rate_limited
      flash.now[:alert] = "Too many verification requests. Try again in a minute."
      return render :new, status: :unprocessable_entity
    end

    redirect_to verify_path(email: @user.email), notice: "We sent a verification code to #{@user.email}."
  end

  private

  def redirect_signed_in_users
    redirect_to dashboard_path if signed_in?
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :preferred_name, :username, :email, :password, :password_confirmation)
  end
end
