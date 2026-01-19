require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "verification_code" do
    mail = UserMailer.verification_code
    assert_equal "Your verification code", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
