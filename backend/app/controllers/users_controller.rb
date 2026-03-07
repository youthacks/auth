class UsersController < ApplicationController
  before_action :require_idp_user!

  def show
    @user = @current_idp_user
    render "auth/user", formats: :json, status: :ok
  end
end