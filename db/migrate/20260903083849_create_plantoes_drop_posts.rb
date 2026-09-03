class CreatePlantoesDropPosts < ActiveRecord::Migration[8.1]
  def up
    create_table :plantoes do |t|
      t.date :data, null: false
      t.time :hora_inicio, null: false
      t.time :hora_fim, null: false
      t.string :local
      t.text :observacao

      t.timestamps
    end

    drop_table :posts
  end

  def down
    create_table :posts do |t|
      t.string :title
      t.text :body

      t.timestamps
    end

    drop_table :plantoes
  end
end
