class ApplicationMailer < ActionMailer::Base
  default from: ENV["SMTP_FROM"].presence ||
                Rails.application.credentials.dig(:smtp, :from) ||
                ("Youthacks Auth <auth@youthacks.org>" unless Rails.env.production?)
  layout "mailer"
end
