require "test_helper"

class CategoriaTest < ActiveSupport::TestCase
  test "valid with nome, cor, hora_inicio, hora_fim" do
    categoria = Categoria.new(nome: "Hospital X", cor: "#4f46e5", hora_inicio: "07:00", hora_fim: "19:00")
    assert categoria.valid?
  end

  test "invalid without nome" do
    categoria = Categoria.new(nome: nil, cor: "#4f46e5", hora_inicio: "07:00", hora_fim: "19:00")
    assert_not categoria.valid?
  end

  test "invalid without cor" do
    categoria = Categoria.new(nome: "Hospital X", cor: nil, hora_inicio: "07:00", hora_fim: "19:00")
    assert_not categoria.valid?
  end

  test "invalid without hora_inicio" do
    categoria = Categoria.new(nome: "Hospital X", cor: "#4f46e5", hora_inicio: nil, hora_fim: "19:00")
    assert_not categoria.valid?
  end

  test "invalid without hora_fim" do
    categoria = Categoria.new(nome: "Hospital X", cor: "#4f46e5", hora_inicio: "07:00", hora_fim: nil)
    assert_not categoria.valid?
  end

  test "invalid when hora_fim is before hora_inicio" do
    categoria = Categoria.new(nome: "Hospital X", cor: "#4f46e5", hora_inicio: "19:00", hora_fim: "07:00")
    assert_not categoria.valid?
    assert_includes categoria.errors[:hora_fim], "deve ser depois do horário de início"
  end

  test "invalid when hora_fim equals hora_inicio" do
    categoria = Categoria.new(nome: "Hospital X", cor: "#4f46e5", hora_inicio: "07:00", hora_fim: "07:00")
    assert_not categoria.valid?
  end
end
