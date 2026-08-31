require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get profile" do
    get profile_url
    assert_response :success
  end

  test "should get settings" do
    get settings_url
    assert_response :success
  end
end
