module Admin
  class ClientsController < ApplicationController
    before_action :require_admin!
    before_action :set_client, only: [ :show, :edit, :update, :destroy ]

    def index
      @clients = Doorkeeper::Application.order(created_at: :desc)
    end

    def show
      # A freshly created client's secret is shown exactly once, via flash.
      @client_secret = flash[:client_secret]
    end

    def new
      @client = Doorkeeper::Application.new
    end

    def create
      @client = Doorkeeper::Application.new(client_params)

      if @client.save
        flash[:client_secret] = @client.plaintext_secret
        redirect_to admin_client_path(@client), notice: "Client created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @client.update(client_params)
        redirect_to admin_client_path(@client), notice: "Client updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @client.destroy
      redirect_to admin_clients_path, notice: "Client deleted.", status: :see_other
    end

    private

    def set_client
      @client = Doorkeeper::Application.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_clients_path, alert: "Client not found."
    end

    def client_params
      permitted = params.require(:client).permit(:name, :redirect_uri)
      permitted[:redirect_uri] = normalize_redirect_uris(permitted[:redirect_uri]).join("\n")
      permitted[:scopes] = Doorkeeper.configuration.default_scopes.to_s
      permitted[:confidential] = true
      permitted
    end

    def normalize_redirect_uris(raw)
      raw.to_s.split(/\r?\n|\s+/).map(&:strip).reject(&:blank?).uniq
    end
  end
end
