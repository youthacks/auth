class ApplicationController < ActionController::API
	include ActionController::Cookies
	before_action :force_json_format

	rescue_from StandardError, with: :handle_unexpected_error

	private

	def force_json_format
		return if request.format.json?

		request.format = :json
	end

	def issue_idp_session(user)
		payload = {
			sub: user.id,
			exp: 1.day.from_now.to_i,
			iat: Time.current.to_i,
			type: "idp"
		}

		JWT.encode(payload, Rails.application.secret_key_base, "HS256")
	end

	def current_idp_user
		token = cookies.encrypted[:idp_session].to_s
		return nil if token.blank?

		decoded, = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: "HS256" })
		return nil unless decoded["type"] == "idp"

		User.find_by(id: decoded["sub"])
	rescue JWT::DecodeError
		nil
	end

	def handle_unexpected_error(error)
		Rails.logger.error("Unhandled error: #{error.class} - #{error.message}")
		Rails.logger.error(error.backtrace.join("\n")) if error.backtrace

		@error = "Server error. Please try again or contact us at hello@youthacks.org"
		render "shared/error", formats: :json, status: :internal_server_error
	end
end
