require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

  test "should get profile" do
    get profile_url
    assert_response :success
  end

  test "should get settings" do
    get settings_url
    assert_response :success
  end
end
