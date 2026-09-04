class CreateCategorias < ActiveRecord::Migration[8.1]
  def change
    create_table :categorias do |t|
      t.string :nome, null: false
      t.string :cor, null: false
      t.time :hora_inicio, null: false
      t.time :hora_fim, null: false

      t.timestamps
    end
  end
end
