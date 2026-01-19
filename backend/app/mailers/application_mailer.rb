class ApplicationMailer < ActionMailer::Base
  DEFAULT_FROM_EMAIL = "auth@youthacks.org"

  default from: ENV.fetch("FROM_EMAIL", DEFAULT_FROM_EMAIL)
  layout "mailer"
end

