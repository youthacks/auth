# Mixed into Doorkeeper's authorization and token controllers: public
# (non-confidential) clients are rejected before any grant is processed.
module Oauth
  module ConfidentialClientsOnly
    extend ActiveSupport::Concern

    included do
      before_action :reject_non_confidential_client
    end

    private

    def reject_non_confidential_client
      client_id = params[:client_id].presence || basic_auth_client_id
      return if client_id.blank?

      client = Doorkeeper::Application.find_by(uid: client_id)
      return if client.nil? || client.confidential?

      render json: {
        error: "unauthorized_client",
        error_description: "Only confidential clients are supported"
      }, status: :unauthorized
    end

    def basic_auth_client_id
      credentials = ActionController::HttpAuthentication::Basic.authenticate(request) { |user, _password| user }
      credentials.presence
    rescue ArgumentError
      nil
    end
  end
end
