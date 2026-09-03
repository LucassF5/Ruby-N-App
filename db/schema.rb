# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_03_120036) do
  create_table "categorias", force: :cascade do |t|
    t.string "cor", null: false
    t.datetime "created_at", null: false
    t.time "hora_fim", null: false
    t.time "hora_inicio", null: false
    t.string "nome", null: false
    t.datetime "updated_at", null: false
  end

  create_table "plantoes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "data", null: false
    t.time "hora_fim", null: false
    t.time "hora_inicio", null: false
    t.string "local"
    t.text "observacao"
    t.datetime "updated_at", null: false
  end
end
