class WelcomeController < ApplicationController
  def show
    render "welcome/show", status: :ok
  end
end
