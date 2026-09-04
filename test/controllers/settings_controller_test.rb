require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

  test "should get edit" do
    get edit_settings_url
    assert_response :success
  end

  test "updates name and email" do
    patch settings_url, params: { user: { name: "Jane Updated", email_address: "jane.updated@example.com" } }
    assert_redirected_to edit_settings_url
    assert_equal "Jane Updated", users(:jane).reload.name
    assert_equal "jane.updated@example.com", users(:jane).reload.email_address
  end

  test "updates password when current password is correct" do
    patch settings_url, params: { user: { current_password: "password", password: "newpassword", password_confirmation: "newpassword" } }
    assert_redirected_to edit_settings_url
    assert users(:jane).reload.authenticate("newpassword")
  end

  test "rejects password change when current password is wrong" do
    patch settings_url, params: { user: { current_password: "wrong", password: "newpassword", password_confirmation: "newpassword" } }
    assert_response :unprocessable_entity
    assert_not users(:jane).reload.authenticate("newpassword")
  end
end
