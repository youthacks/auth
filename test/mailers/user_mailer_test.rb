require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "verification_code" do
    mail = UserMailer.with(email: "to@example.org", code: "123456", expires_in: 10).verification_code
    assert_equal "Youthacks Auth Verification Code - 123456", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_match "123456", mail.body.encoded
    assert_match "10 minutes", mail.body.encoded
  end
end
