class ErrorsController < ApplicationController
  def not_found
    @error = "Endpoint not found"
    render "shared/error", status: :not_found
  end
end
