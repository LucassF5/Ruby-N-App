require "test_helper"

class ShiftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
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

  test "should create shift with category filling times automatically" do
    category = categories(:hospital_x)

    assert_difference("Shift.count") do
      post shifts_url, params: { shift: { date: "2026-09-20", category_id: category.id } }
    end

    shift = Shift.last
    assert_equal category.start_time, shift.start_time
    assert_equal category.end_time, shift.end_time
  end

  test "should redirect to return_to when it is a relative path" do
    post shifts_url, params: { shift: { date: "2026-09-21", start_time: "08:00", end_time: "12:00" }, return_to: "/calendar" }
    assert_redirected_to "/calendar"
  end

  test "should ignore return_to when it is not a relative path" do
    post shifts_url, params: { shift: { date: "2026-09-22", start_time: "08:00", end_time: "12:00" }, return_to: "https://evil.example.com" }
    assert_redirected_to root_url
  end

  test "should ignore return_to when it is a protocol-relative path" do
    post shifts_url, params: { shift: { date: "2026-09-23", start_time: "08:00", end_time: "12:00" }, return_to: "//evil.example.com" }
    assert_redirected_to root_url
  end

  test "should destroy shift and redirect to return_to" do
    assert_difference("Shift.count", -1) do
      delete shift_url(@shift), params: { return_to: "/calendar" }
    end
    assert_redirected_to "/calendar"
  end
end
