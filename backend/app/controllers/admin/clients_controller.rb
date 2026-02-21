module Admin
  class ClientsController < ApplicationController
    before_action :require_admin!
    before_action :set_application, only: [:show, :update, :destroy]

    def index
      apps = Doorkeeper::Application.all.order(created_at: :desc)
      render json: apps.as_json(only: [:id, :name, :uid, :redirect_uri, :scopes, :confidential, :created_at])
    end

    def show
      render json: @app.as_json(only: [:id, :name, :uid, :redirect_uri, :scopes, :confidential, :created_at])
    end

    def create
      app = Doorkeeper::Application.new(application_params)
      if app.save
        render json: app.as_json(only: [:id, :name, :uid, :redirect_uri, :scopes, :confidential]).merge(secret: app.secret), status: :created
      else
        render json: { errors: app.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @app.update(application_params)
        render json: @app.as_json(only: [:id, :name, :uid, :redirect_uri, :scopes, :confidential])
      else
        render json: { errors: @app.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @app.destroy
      head :no_content
    end

    private

    def require_admin!
      user = current_idp_user
      unless user && user.respond_to?(:admin?) && user.admin?
        head :forbidden
      end
    end

    def set_application
      @app = Doorkeeper::Application.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'application not found' }, status: :not_found
    end

    def application_params
      params.require(:application).permit(:name, :redirect_uri, :scopes, :confidential)
    end
  end
end
