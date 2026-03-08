module Admin
  class ClientsController < ApplicationController
    DEFAULT_CLIENT_SCOPES = Doorkeeper.configuration.default_scopes.to_s.freeze

    before_action :require_admin!
    before_action :set_application, only: [:show, :update, :destroy]

    def index
      @clients = Doorkeeper::Application.all.order(created_at: :desc)
      render :index, status: :ok
    end

    def show
      @client = @app
      render :show, status: :ok
    end

    def create
      app = Doorkeeper::Application.new(application_params)
      if app.save
        @message = "Client created"
        @client = app
        @client_secret = app.secret
        render :create, status: :created
      else
        render_error("Validation failed", status: :unprocessable_entity, errors: app.errors.full_messages)
      end
    end

    def update
      if @app.update(application_params)
        @message = "Client updated"
        @client = @app
        render :update, status: :ok
      else
        render_error("Validation failed", status: :unprocessable_entity, errors: @app.errors.full_messages)
      end
    end

    def destroy
      if @app.destroy
        @message = "Client deleted"
        render :destroy, status: :ok
      else
        render_error("Validation failed", status: :unprocessable_entity, errors: @app.errors.full_messages)
      end
    end

    private

    def require_admin!
      user = current_idp_user
      if user.nil?
        render_error("User not found or not authenticated", status: :unauthorized)
        return
      end

      return if user.admin?

      render_error("Forbidden", status: :forbidden)
      return
    end

    def set_application
      @app = Doorkeeper::Application.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_error("Application not found", status: :not_found)
      nil
    end

    def application_params
      permitted = params.require(:application).permit(:name, :redirect_uri)
      permitted[:scopes] = DEFAULT_CLIENT_SCOPES
      permitted[:confidential] = true
      permitted
    end

  end
end
