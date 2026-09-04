require "test_helper"

class OmniauthControllerTest < ActionDispatch::IntegrationTest
  test "creates a new user and session from Apple auth" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.1234",
      info: { email: "new.apple.user@example.com", name: "Apple User" }
    )

    assert_difference("User.count") do
      get "/auth/apple/callback"
    end

    user = User.find_by(email_address: "new.apple.user@example.com")
    assert_equal "apple", user.provider
    assert_equal "001999.abcdef.1234", user.uid
    assert_redirected_to root_url
  end

  test "links an existing email/password account by email on first Apple sign-in" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.5678",
      info: { email: users(:jane).email_address, name: "Jane Doe" }
    )

    assert_no_difference("User.count") do
      get "/auth/apple/callback"
    end

    assert_equal "apple", users(:jane).reload.provider
  end

  test "reuses the same user on a repeat Apple sign-in" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.1234",
      info: { email: "repeat@example.com", name: "Repeat User" }
    )
    get "/auth/apple/callback"

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.1234",
      info: {}
    )
    assert_no_difference("User.count") do
      get "/auth/apple/callback"
    end
  end
end
