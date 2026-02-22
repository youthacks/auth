class ApplicationController < ActionController::API
	# include ActionController::Cookies # Removed: switched to session-based storage
	before_action :force_json_format

	rescue_from StandardError, with: :handle_error

	private

	def force_json_format
		return if request.format.json?

		request.format = :json
	end

	def handle_error(error)
		Rails.logger.error("Unhandled error: #{error.class} - #{error.message}")
		Rails.logger.error(error.backtrace.join("\n")) if error.backtrace

		@error = "Server error. Please try again or contact us at hello@youthacks.org."
		render "shared/error", formats: :json, status: :internal_server_error
	end
end
