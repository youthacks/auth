class ApplicationMailer < ActionMailer::Base

  default from: ENV.fetch("SMTP_FROM") ? ENV.fetch("SMTP_FROM") : Rails.application.credentials.dig(:smtp, :from)
  layout "mailer"
end

