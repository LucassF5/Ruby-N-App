require "test_helper"

class CategoriasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @categoria = categorias(:hospital_x)
  end

  test "should get index" do
    get categorias_url
    assert_response :success
  end

  test "should get new" do
    get new_categoria_url
    assert_response :success
  end

  test "should create categoria" do
    assert_difference("Categoria.count") do
      post categorias_url, params: { categoria: { nome: "Hospital Y", cor: "#f97316", hora_inicio: "08:00", hora_fim: "20:00" } }
    end

    assert_redirected_to categorias_url
  end

  test "should not create categoria with invalid times" do
    assert_no_difference("Categoria.count") do
      post categorias_url, params: { categoria: { nome: "Hospital Y", cor: "#f97316", hora_inicio: "20:00", hora_fim: "08:00" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_categoria_url(@categoria)
    assert_response :success
  end

  test "should update categoria" do
    patch categoria_url(@categoria), params: { categoria: { nome: "Hospital X Renovado" } }
    assert_redirected_to categorias_url
    assert_equal "Hospital X Renovado", @categoria.reload.nome
  end

  test "should destroy categoria" do
    assert_difference("Categoria.count", -1) do
      delete categoria_url(@categoria)
    end

    assert_redirected_to categorias_url
  end

  test "destroying categoria nullifies associated plantoes instead of blocking" do
    plantao = Plantao.create!(data: Date.new(2026, 9, 10), categoria: @categoria)

    delete categoria_url(@categoria)

    assert_nil plantao.reload.categoria_id
  end
end
