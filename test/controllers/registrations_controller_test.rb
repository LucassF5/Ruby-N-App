require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "creates an account and signs in" do
    assert_difference("User.count") do
      post registrations_url, params: { user: { name: "Nova Silva", email_address: "nova@example.com", password: "password", password_confirmation: "password" } }
    end

    assert_redirected_to root_url
  end

  test "does not create an account with a duplicate email" do
    assert_no_difference("User.count") do
      post registrations_url, params: { user: { name: "Dup", email_address: users(:jane).email_address, password: "password", password_confirmation: "password" } }
    end

    assert_response :unprocessable_entity
  end

  test "does not create an account with mismatched password confirmation" do
    assert_no_difference("User.count") do
      post registrations_url, params: { user: { name: "Dup", email_address: "dup2@example.com", password: "password", password_confirmation: "different" } }
    end

    assert_response :unprocessable_entity
  end
end
