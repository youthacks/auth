module Admin
  class ClientsController < ApplicationController
    before_action :require_admin!
    before_action :set_application, only: [:show, :update, :destroy]

    def index
      @clients = Doorkeeper::Application.all.order(created_at: :desc)
    end

    def show
      @client = @app
    end

    def create
      app = Doorkeeper::Application.new(application_params)
      if app.save
        @message = "Client created"
        @client = app
        @client_secret = app.secret
        render :create, status: :created
      else
        @errors = app.errors.full_messages
        render "shared/errors", formats: :json, status: :unprocessable_entity
      end
    end

    def update
      if @app.update(application_params)
        @message = "Client updated"
        @client = @app
      else
        @errors = @app.errors.full_messages
        render "shared/errors", formats: :json, status: :unprocessable_entity
      end
    end

    def destroy
      if @app.destroy
        @message = "Client deleted"
      else
        @errors = @app.errors.full_messages
        render "shared/errors", formats: :json, status: :unprocessable_entity
      end
    end

    private

    def require_admin!
      user = current_idp_user
      if user.nil?
        @error = "User not found or not authenticated"
        render "shared/error", formats: :json, status: :unauthorized
        return
      end

      return if user.admin?

      @error = "Forbidden"
      render "shared/error", formats: :json, status: :forbidden
      return
    end

    def set_application
      @app = Doorkeeper::Application.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      @error = "Application not found"
      render "shared/error", formats: :json, status: :not_found
      nil
    end

    def application_params
      params.require(:application).permit(:name, :redirect_uri, :scopes, :confidential)
    end

  end
end
