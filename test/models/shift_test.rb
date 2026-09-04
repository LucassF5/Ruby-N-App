require "test_helper"

class ShiftTest < ActiveSupport::TestCase
  test "valid with date, start_time, end_time" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "14:00")
    assert shift.valid?
  end

  test "invalid without date" do
    shift = Shift.new(date: nil, start_time: "08:00", end_time: "14:00")
    assert_not shift.valid?
  end

  test "invalid without start_time" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: nil, end_time: "14:00")
    assert_not shift.valid?
  end

  test "invalid without end_time" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "08:00", end_time: nil)
    assert_not shift.valid?
  end

  test "invalid when end_time is before start_time" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "14:00", end_time: "08:00")
    assert_not shift.valid?
    assert_includes shift.errors[:end_time], "deve ser depois do horário de início"
  end

  test "invalid when end_time equals start_time" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "08:00")
    assert_not shift.valid?
  end

  test "valid without location or notes" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "14:00", location: nil, notes: nil)
    assert shift.valid?
  end

  test "valid with category and no explicit start_time/end_time" do
    category = categories(:hospital_x)
    shift = Shift.new(date: Date.new(2026, 9, 10), category: category)

    assert shift.valid?
    assert_equal category.start_time, shift.start_time
    assert_equal category.end_time, shift.end_time
  end

  test "keeps explicit start_time/end_time even with category set" do
    category = categories(:hospital_x)
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "09:00", end_time: "10:00", category: category)

    assert shift.valid?
    assert_equal "09:00", shift.start_time.strftime("%H:%M")
    assert_equal "10:00", shift.end_time.strftime("%H:%M")
  end

  test "valid without category" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "14:00")
    assert shift.valid?
    assert_nil shift.category
  end

  test "destroying category nullifies associated shift" do
    category = categories(:hospital_x)
    shift = Shift.create!(date: Date.new(2026, 9, 10), category: category)

    category.destroy

    assert_nil shift.reload.category_id
  end
end
