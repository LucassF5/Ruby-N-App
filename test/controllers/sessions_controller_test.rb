require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "signs in with valid credentials" do
    post session_url, params: { email_address: users(:jane).email_address, password: "password" }
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
  end

  test "rejects invalid credentials" do
    post session_url, params: { email_address: users(:jane).email_address, password: "wrong" }
    assert_redirected_to new_session_url
  end

  test "signs out" do
    sign_in_as users(:jane)
    delete session_url
    assert_redirected_to new_session_url
  end

  test "redirects unauthenticated visitors to sign in" do
    get root_url
    assert_redirected_to new_session_url

    get profile_url
    assert_redirected_to new_session_url

    get categories_url
    assert_redirected_to new_session_url

    get calendar_url
    assert_redirected_to new_session_url
  end
end
