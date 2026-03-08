class ErrorsController < ApplicationController
  def not_found
    render_error("Endpoint not found", status: :not_found)
  end
end
