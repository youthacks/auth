class UserMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.verification_code.subject
  #
  def verification_code
    @code = params[:code]
    @expires_in = params[:expires_in] || 15 # default to 15 minutes
    mail(to: params[:email], subject: "Your verification code")
  end
end
