class ApplicationController < ActionController::Base
  include Authentication

  rescue_from ActionController::InvalidAuthenticityToken do
    redirect_back fallback_location: root_path, alert: "Your session expired. Please try again."
  end

  private

  # Only allow redirects back to paths on this app (never to another host).
  def safe_return_to(value)
    value = value.to_s
    return nil if value.blank?

    uri = URI.parse(value)
    return nil if uri.host.present? || uri.scheme.present?
    return nil unless uri.path.start_with?("/") && !uri.path.start_with?("//")
    return nil if uri.path == login_path

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end
end
