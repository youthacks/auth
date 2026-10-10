# frozen_string_literal: true

# Fail fast at boot if required configuration is missing in production, instead
# of failing lazily at the first request, database query, or email send.
#
# SMTP values honor the same ENV-or-credentials fallback used in
# config/environments/production.rb, so setting either source satisfies the check.
if Rails.env.production?
  missing = []

  # No fallback: Rails and the database layer need these directly.
  missing << "SECRET_KEY_BASE" if ENV["SECRET_KEY_BASE"].blank?
  missing << "DATABASE_URL" if ENV["DATABASE_URL"].blank?

  # OIDC issuer and mailer host come from APP_URL (preferred) or FRONTEND_URL.
  if ENV["APP_URL"].blank? && ENV["FRONTEND_URL"].blank?
    missing << "APP_URL (or FRONTEND_URL)"
  end

  # SMTP: ENV first, then encrypted credentials under smtp/*.
  creds = Rails.application.credentials
  missing << "SMTP_HOST (or credentials smtp.host)" if (ENV["SMTP_HOST"].presence || creds.dig(:smtp, :host)).blank?
  missing << "SMTP_USER (or credentials smtp.user_name)" if (ENV["SMTP_USER"].presence || creds.dig(:smtp, :user_name)).blank?
  missing << "SMTP_PASS (or credentials smtp.password)" if (ENV["SMTP_PASS"].presence || creds.dig(:smtp, :password)).blank?

  if missing.any?
    raise "Missing required configuration in production: #{missing.join(', ')}"
  end
end
