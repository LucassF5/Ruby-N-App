require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "reset renders both html and text bodies" do
    mail = PasswordsMailer.reset(users(:jane))

    assert_equal "Redefinir senha", mail.subject
    assert_equal [users(:jane).email_address], mail.to
    assert_match "Redefinir senha", mail.html_part.body.to_s
    assert_match "Redefinir senha", mail.text_part.body.to_s
  end
end
