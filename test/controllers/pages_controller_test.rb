require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

  test "should get profile" do
    get profile_url
    assert_response :success
  end

  test "profile shows the signed-in user's name and email" do
    get profile_url
    assert_match users(:jane).name, response.body
    assert_match users(:jane).email_address, response.body
  end
end
