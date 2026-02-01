class WelcomeController < ApplicationController
  def show
    render json: {
      message: "Youthacks Auth API",
      status: "ok"
    }, status: :ok
  end
end
