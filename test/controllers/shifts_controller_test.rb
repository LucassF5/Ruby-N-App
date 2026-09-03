require "test_helper"

class PlantoesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @plantao = plantoes(:um)
  end

  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should get new" do
    get new_plantao_url
    assert_response :success
  end

  test "should create plantao" do
    assert_difference("Plantao.count") do
      post plantoes_url, params: { plantao: { data: "2026-09-15", hora_inicio: "09:00", hora_fim: "17:00", local: "Posto Sul" } }
    end

    assert_redirected_to root_url
  end

  test "should not create plantao with invalid times" do
    assert_no_difference("Plantao.count") do
      post plantoes_url, params: { plantao: { data: "2026-09-15", hora_inicio: "17:00", hora_fim: "09:00" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_plantao_url(@plantao)
    assert_response :success
  end

  test "should update plantao" do
    patch plantao_url(@plantao), params: { plantao: { local: "Novo Local" } }
    assert_redirected_to root_url
    assert_equal "Novo Local", @plantao.reload.local
  end

  test "should not update plantao with invalid times" do
    patch plantao_url(@plantao), params: { plantao: { hora_inicio: "17:00", hora_fim: "09:00" } }
    assert_response :unprocessable_entity
  end

  test "should destroy plantao" do
    assert_difference("Plantao.count", -1) do
      delete plantao_url(@plantao)
    end

    assert_redirected_to root_url
  end
end
