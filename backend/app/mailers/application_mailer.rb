class ApplicationMailer < ActionMailer::Base

  default from: ENV["SMTP_FROM"].presence || Rails.application.credentials.dig(:smtp, :from)
  layout "mailer"
end

