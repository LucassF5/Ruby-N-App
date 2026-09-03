require "test_helper"

class CalendarControllerTest < ActionDispatch::IntegrationTest
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
    Shift.create!(date: Date.new(2026, 9, 20), category: category)

    get calendar_url(month: "2026-09")

    assert_response :success
    assert_match category.color, response.body
  end

  test "should get day with existing shifts" do
    category = categories(:hospital_x)
    Shift.create!(date: Date.new(2026, 9, 20), category: category)

    get calendar_day_url(date: "2026-09-20")

    assert_response :success
    assert_match category.name, response.body
  end

  test "should get day without shifts" do
    get calendar_day_url(date: "2026-09-25")

    assert_response :success
    assert_match "Nenhum plantão", response.body
  end
end
