require "test_helper"

class CalendarControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

  test "should get calendar for current month" do
    get calendar_url
    assert_response :success
  end

  test "should get calendar for a given month" do
    get calendar_url(month: "2026-12")
    assert_response :success
  end

  test "should show a colored dot for a day with a category shift" do
    category = categories(:hospital_x)
    Shift.create!(user: users(:jane), date: Date.new(2026, 9, 20), category: category)

    get calendar_url(month: "2026-09")

    assert_response :success
    assert_match category.color, response.body
  end

  test "should get day with existing shifts" do
    category = categories(:hospital_x)
    Shift.create!(user: users(:jane), date: Date.new(2026, 9, 20), category: category)

    get calendar_day_url(date: "2026-09-20")

    assert_response :success
    assert_match category.name, response.body
  end

  test "should get day without shifts" do
    get calendar_day_url(date: "2026-09-25")

    assert_response :success
    assert_match "Nenhum plantão", response.body
  end

  test "should show empty-category guidance instead of form when no categories exist" do
    Category.delete_all

    get calendar_day_url(date: "2026-09-25")

    assert_response :success
    assert_match "Cadastre uma categoria", response.body
  end

  test "should show a colored dot for a shift on a previous-month padding day" do
    category = categories(:hospital_x)
    Shift.create!(user: users(:jane), date: Date.new(2026, 8, 31), category: category)

    get calendar_url(month: "2026-09")

    assert_response :success
    assert_match category.color, response.body
  end

  test "does not show another user's shift on the calendar" do
    Shift.create!(user: users(:john), date: Date.new(2026, 9, 20), start_time: "08:00", end_time: "12:00", location: "Clínica de John")

    get calendar_day_url(date: "2026-09-20")

    assert_response :success
    assert_no_match "Clínica de John", response.body
  end
end
