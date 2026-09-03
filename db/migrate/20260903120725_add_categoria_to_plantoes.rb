class AddCategoriaToPlantoes < ActiveRecord::Migration[8.1]
  def change
    add_reference :plantoes, :categoria, foreign_key: true, null: true
  end
end
