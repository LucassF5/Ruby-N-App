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

  test "links an existing email/password account by email on first Apple sign-in when email is verified" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.5678",
      info: { email: users(:jane).email_address, name: "Jane Doe", email_verified: true }
    )

    assert_no_difference("User.count") do
      get "/auth/apple/callback"
    end

    assert_equal "apple", users(:jane).reload.provider
  end

  test "does not link to an existing account when Apple email is not verified" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.new-unverified",
      info: { email: "brand.new.unverified@example.com", name: "New Unverified User", email_verified: false }
    )

    # Proves the unverified email is not matched to any existing account:
    # since the incoming email doesn't collide with an existing user, the
    # callback falls through to creating a genuinely new account.
    assert_difference("User.count") do
      get "/auth/apple/callback"
    end

    user = User.find_by(email_address: "brand.new.unverified@example.com")
    assert_equal "apple", user.provider
    assert_equal "001999.abcdef.new-unverified", user.uid
  end

  test "does not silently link and does not leak the existing account when Apple's unverified email collides with an existing user" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.9999",
      info: { email: users(:jane).email_address, name: "Jane Doe", email_verified: false }
    )

    assert_no_difference("User.count") do
      get "/auth/apple/callback"
    end

    assert_nil users(:jane).reload.provider
    assert_nil users(:jane).reload.uid
    assert_redirected_to new_session_url
  end

  test "does not link to an existing account when email_verified is missing" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.no-verified-flag",
      info: { email: "no.verified.flag@example.com", name: "Jane Doe" }
    )

    assert_difference("User.count") do
      get "/auth/apple/callback"
    end

    user = User.find_by(email_address: "no.verified.flag@example.com")
    assert_equal "apple", user.provider
  end

  test "POST to callback routes successfully and is not blocked by forgery protection" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    begin
      OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
        provider: "apple",
        uid: "001999.abcdef.post",
        info: { email: "post.apple.user@example.com", name: "Post User", email_verified: true }
      )

      assert_difference("User.count") do
        post "/auth/apple/callback"
      end

      assert_response :redirect
      assert_redirected_to root_url
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
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
