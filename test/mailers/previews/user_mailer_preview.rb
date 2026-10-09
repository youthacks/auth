# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/verification_code
  def verification_code
    UserMailer.with(email: "someone@example.com", code: "123456", expires_in: 10).verification_code
  end
end
