require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
    @category = categories(:hospital_x)
  end

  test "should get index" do
    get categories_url
    assert_response :success
  end

  test "should get new" do
    get new_category_url
    assert_response :success
  end

  test "should create category" do
    assert_difference("Category.count") do
      post categories_url, params: { category: { name: "Hospital Y", color: "#f97316", start_time: "08:00", end_time: "20:00" } }
    end

    assert_redirected_to categories_url
  end

  test "should not create category with invalid times" do
    assert_no_difference("Category.count") do
      post categories_url, params: { category: { name: "Hospital Y", color: "#f97316", start_time: "20:00", end_time: "08:00" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_category_url(@category)
    assert_response :success
  end

  test "should update category" do
    patch category_url(@category), params: { category: { name: "Hospital X Renovado" } }
    assert_redirected_to categories_url
    assert_equal "Hospital X Renovado", @category.reload.name
  end

  test "should destroy category" do
    assert_difference("Category.count", -1) do
      delete category_url(@category)
    end

    assert_redirected_to categories_url
  end

  test "destroying category nullifies associated shifts instead of blocking" do
    shift = Shift.create!(user: users(:jane), date: Date.new(2026, 9, 10), category: @category)

    delete category_url(@category)

    assert_nil shift.reload.category_id
  end

  test "cannot edit another user's category" do
    other_category = Category.create!(user: users(:john), name: "Clínica Y", color: "#000000", start_time: "08:00", end_time: "16:00")

    get edit_category_url(other_category)

    assert_response :not_found
  end

  test "created category belongs to the signed-in user" do
    post categories_url, params: { category: { name: "Hospital Y", color: "#f97316", start_time: "08:00", end_time: "20:00" } }
    assert_equal users(:jane), Category.last.user
  end
end
