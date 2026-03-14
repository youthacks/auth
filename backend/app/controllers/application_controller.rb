class ApplicationController < ActionController::API
	include ActionController::Cookies

	ACCESS_TOKEN_COOKIE = :idp_access_token

	before_action :force_json_format

	rescue_from StandardError, with: :handle_error

	private

	def force_json_format
		return if request.format.json?

		request.format = :json
	end

	def render_error(message, status: :unprocessable_entity, errors: nil)
		@error = message
		@errors = errors if errors.present?

		if errors.present?
				render "shared/errors", status: status
		else
				render "shared/error", status: status
		end
	end

	def render_message(message, status: :ok, extra: {})
		@message = message
		extra.each { |key, value| instance_variable_set("@#{key}", value) }
		render "shared/errors", status: status
	end

	def handle_error(error)
		Rails.logger.error("Unhandled error: #{error.class} - #{error.message}")
		Rails.logger.error(error.backtrace.join("\n")) if error.backtrace

		render_error(
			"Server error. Please try again or contact us at hello@youthacks.org.",
			status: :internal_server_error
		)
	end

	def current_idp_user
		raw_token = bearer_token || oauth_handoff_token || cookie_token
		return nil if raw_token.blank?

		digest = AccessToken.digest(raw_token)
		token_record = AccessToken.active.find_by(token_digest: digest)
		return nil unless token_record && !token_record.expired?

		token_record.update!(last_used_at: Time.current)
		token_record.user
	end

	def bearer_token
		auth_header = request.headers["Authorization"].to_s
		return nil unless auth_header.start_with?("Bearer ")

		auth_header.split(" ", 2)[1]
	end

	def oauth_handoff_token
		return nil unless request.path.start_with?("/oauth/")

		params[:idp_token].to_s.presence
	end

	def cookie_token
		cookies.encrypted[ACCESS_TOKEN_COOKIE].to_s.presence
	end

	def access_token_cookie_options
		{
			http_only: true,
			secure: Rails.env.production?,
			same_site: :lax,
			expires: AccessToken::TTL.from_now
		}
	end

	def set_access_token_cookie(raw_token)
		cookies.encrypted[ACCESS_TOKEN_COOKIE] = access_token_cookie_options.merge(value: raw_token)
	end

	def clear_access_token_cookie
		cookies.delete(ACCESS_TOKEN_COOKIE, access_token_cookie_options.except(:expires))
	end

	def require_idp_user!
		@current_idp_user = current_idp_user
		return if @current_idp_user

		render_error("User not found or not authenticated", status: :unauthorized)
	end
end
