require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

  test "should get show" do
    get profile_url
    assert_response :success
  end

  test "show displays the signed-in user's name and email" do
    get profile_url
    assert_match users(:jane).name, response.body
    assert_match users(:jane).email_address, response.body
  end

  test "should get edit" do
    get edit_profile_url
    assert_response :success
  end

  test "updates name and email" do
    patch profile_url, params: { user: { name: "Jane Updated", email_address: "jane.updated@example.com", current_password: "password" } }
    assert_redirected_to profile_url
    assert_equal "Jane Updated", users(:jane).reload.name
    assert_equal "jane.updated@example.com", users(:jane).reload.email_address
  end

  test "rejects email change without current password" do
    patch profile_url, params: { user: { email_address: "jane.updated@example.com" } }
    assert_response :unprocessable_entity
    assert_equal "jane@example.com", users(:jane).reload.email_address
  end

  test "rejects email change with wrong current password" do
    patch profile_url, params: { user: { email_address: "jane.updated@example.com", current_password: "wrong" } }
    assert_response :unprocessable_entity
    assert_equal "jane@example.com", users(:jane).reload.email_address
  end

  test "updates password when current password is correct" do
    patch profile_url, params: { user: { current_password: "password", password: "newpassword", password_confirmation: "newpassword" } }
    assert_redirected_to profile_url
    assert users(:jane).reload.authenticate("newpassword")
  end

  test "rejects password change when current password is wrong" do
    patch profile_url, params: { user: { current_password: "wrong", password: "newpassword", password_confirmation: "newpassword" } }
    assert_response :unprocessable_entity
    assert_not users(:jane).reload.authenticate("newpassword")
  end

  test "updates avatar" do
    file = fixture_file_upload("avatar.png", "image/png")

    patch profile_url, params: { user: { avatar: file } }

    assert_redirected_to profile_url
    assert users(:jane).reload.avatar.attached?
  end

  test "rejects avatar with disallowed content type" do
    file = fixture_file_upload("not_an_image.txt", "text/plain")

    patch profile_url, params: { user: { avatar: file } }

    assert_response :unprocessable_entity
    assert_not users(:jane).reload.avatar.attached?
  end

  test "destroys other sessions after password change" do
    other_session = open_session
    other_session.post session_url, params: { email_address: users(:jane).email_address, password: "password" }
    other_session_id = users(:jane).sessions.order(:created_at).last.id

    patch profile_url, params: { user: { current_password: "password", password: "newpassword", password_confirmation: "newpassword" } }
    assert_redirected_to profile_url

    assert_nil Session.find_by(id: other_session_id)

    other_session.get profile_url
    other_session.assert_redirected_to new_session_url
  end
end
