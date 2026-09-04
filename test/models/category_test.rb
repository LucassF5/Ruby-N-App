require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "valid with name, color, start_time, end_time" do
    category = Category.new(name: "Hospital X", color: "#4f46e5", start_time: "07:00", end_time: "19:00")
    assert category.valid?
  end

  test "invalid without name" do
    category = Category.new(name: nil, color: "#4f46e5", start_time: "07:00", end_time: "19:00")
    assert_not category.valid?
  end

  test "invalid without color" do
    category = Category.new(name: "Hospital X", color: nil, start_time: "07:00", end_time: "19:00")
    assert_not category.valid?
  end

  test "invalid without start_time" do
    category = Category.new(name: "Hospital X", color: "#4f46e5", start_time: nil, end_time: "19:00")
    assert_not category.valid?
  end

  test "invalid without end_time" do
    category = Category.new(name: "Hospital X", color: "#4f46e5", start_time: "07:00", end_time: nil)
    assert_not category.valid?
  end

  test "invalid when end_time is before start_time" do
    category = Category.new(name: "Hospital X", color: "#4f46e5", start_time: "19:00", end_time: "07:00")
    assert_not category.valid?
    assert_includes category.errors[:end_time], "deve ser depois do horário de início"
  end

  test "invalid when end_time equals start_time" do
    category = Category.new(name: "Hospital X", color: "#4f46e5", start_time: "07:00", end_time: "07:00")
    assert_not category.valid?
  end
end
