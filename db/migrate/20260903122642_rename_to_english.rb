class RenameToEnglish < ActiveRecord::Migration[8.1]
  def change
    rename_table :plantoes, :shifts
    rename_table :categorias, :categories

    rename_column :shifts, :data, :date
    rename_column :shifts, :hora_inicio, :start_time
    rename_column :shifts, :hora_fim, :end_time
    rename_column :shifts, :local, :location
    rename_column :shifts, :observacao, :notes
    rename_column :shifts, :categoria_id, :category_id

    rename_column :categories, :nome, :name
    rename_column :categories, :cor, :color
    rename_column :categories, :hora_inicio, :start_time
    rename_column :categories, :hora_fim, :end_time
  end
end
