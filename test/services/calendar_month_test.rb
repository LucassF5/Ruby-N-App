require "test_helper"

class CalendarMonthTest < ActiveSupport::TestCase
  test "total_hours sums same-day shifts" do
    user = users(:jane)
    Shift.create!(user: user, date: Date.new(2026, 10, 10), start_time: "08:00", end_time: "14:00")

    calendar = CalendarMonth.new(user, month: "2026-10")

    assert_equal 6.0, calendar.total_hours
  end

  test "total_hours counts an overnight shift's full duration, not a negative one" do
    user = users(:jane)
    Shift.create!(user: user, date: Date.new(2026, 10, 10), start_time: "22:00", end_time: "06:00")

    calendar = CalendarMonth.new(user, month: "2026-10")

    assert_equal 8.0, calendar.total_hours
  end
end
