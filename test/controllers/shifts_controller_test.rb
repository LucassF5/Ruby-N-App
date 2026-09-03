require "test_helper"

class ShiftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @shift = shifts(:one)
  end

  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should get new" do
    get new_shift_url
    assert_response :success
  end

  test "should create shift" do
    assert_difference("Shift.count") do
      post shifts_url, params: { shift: { date: "2026-09-15", start_time: "09:00", end_time: "17:00", location: "Posto Sul" } }
    end

    assert_redirected_to root_url
  end

  test "should not create shift with invalid times" do
    assert_no_difference("Shift.count") do
      post shifts_url, params: { shift: { date: "2026-09-15", start_time: "17:00", end_time: "09:00" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_shift_url(@shift)
    assert_response :success
  end

  test "should update shift" do
    patch shift_url(@shift), params: { shift: { location: "Novo Local" } }
    assert_redirected_to root_url
    assert_equal "Novo Local", @shift.reload.location
  end

  test "should not update shift with invalid times" do
    patch shift_url(@shift), params: { shift: { start_time: "17:00", end_time: "09:00" } }
    assert_response :unprocessable_entity
  end

  test "should destroy shift" do
    assert_difference("Shift.count", -1) do
      delete shift_url(@shift)
    end

    assert_redirected_to root_url
  end
end
