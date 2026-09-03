require "test_helper"

class PlantaoTest < ActiveSupport::TestCase
  test "valid with data, hora_inicio, hora_fim" do
    plantao = Plantao.new(data: Date.new(2026, 9, 10), hora_inicio: "08:00", hora_fim: "14:00")
    assert plantao.valid?
  end

  test "invalid without data" do
    plantao = Plantao.new(data: nil, hora_inicio: "08:00", hora_fim: "14:00")
    assert_not plantao.valid?
  end

  test "invalid without hora_inicio" do
    plantao = Plantao.new(data: Date.new(2026, 9, 10), hora_inicio: nil, hora_fim: "14:00")
    assert_not plantao.valid?
  end

  test "invalid without hora_fim" do
    plantao = Plantao.new(data: Date.new(2026, 9, 10), hora_inicio: "08:00", hora_fim: nil)
    assert_not plantao.valid?
  end

  test "invalid when hora_fim is before hora_inicio" do
    plantao = Plantao.new(data: Date.new(2026, 9, 10), hora_inicio: "14:00", hora_fim: "08:00")
    assert_not plantao.valid?
    assert_includes plantao.errors[:hora_fim], "deve ser depois do horário de início"
  end

  test "invalid when hora_fim equals hora_inicio" do
    plantao = Plantao.new(data: Date.new(2026, 9, 10), hora_inicio: "08:00", hora_fim: "08:00")
    assert_not plantao.valid?
  end

  test "valid without local or observacao" do
    plantao = Plantao.new(data: Date.new(2026, 9, 10), hora_inicio: "08:00", hora_fim: "14:00", local: nil, observacao: nil)
    assert plantao.valid?
  end

  test "valid with categoria and no explicit hora_inicio/hora_fim" do
    categoria = categorias(:hospital_x)
    plantao = Plantao.new(data: Date.new(2026, 9, 10), categoria: categoria)

    assert plantao.valid?
    assert_equal categoria.hora_inicio, plantao.hora_inicio
    assert_equal categoria.hora_fim, plantao.hora_fim
  end

  test "keeps explicit hora_inicio/hora_fim even with categoria set" do
    categoria = categorias(:hospital_x)
    plantao = Plantao.new(data: Date.new(2026, 9, 10), hora_inicio: "09:00", hora_fim: "10:00", categoria: categoria)

    assert plantao.valid?
    assert_equal "09:00", plantao.hora_inicio.strftime("%H:%M")
    assert_equal "10:00", plantao.hora_fim.strftime("%H:%M")
  end

  test "valid without categoria" do
    plantao = Plantao.new(data: Date.new(2026, 9, 10), hora_inicio: "08:00", hora_fim: "14:00")
    assert plantao.valid?
    assert_nil plantao.categoria
  end

  test "destroying categoria nullifies associated plantao" do
    categoria = categorias(:hospital_x)
    plantao = Plantao.create!(data: Date.new(2026, 9, 10), categoria: categoria)

    categoria.destroy

    assert_nil plantao.reload.categoria_id
  end
end
