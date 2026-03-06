class CreateCie10Diagnoses < ActiveRecord::Migration[8.1]
  def change
    create_table :cie10_diagnoses, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string :code,        null: false
      t.text   :description, null: false
      t.string :category
      t.string :chapter

      t.timestamps
    end

    add_index :cie10_diagnoses, :code, unique: true
    add_index :cie10_diagnoses, :category
  end
end
