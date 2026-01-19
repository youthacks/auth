require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "verification_code" do
    mail = UserMailer.with(email: "to@example.org", code: "123456", expires_in: 10).verification_code
    assert_equal "Youthacks Auth Verification Code - 123456", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
