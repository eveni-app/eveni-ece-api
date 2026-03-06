class CreateMedicationsCatalog < ActiveRecord::Migration[8.1]
  def change
    create_table :medications_catalogs, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string :cve_code,             null: false
      t.string :name,                 null: false
      t.string :active_ingredient
      t.string :route_of_administration
      t.string :presentation

      t.timestamps
    end

    add_index :medications_catalogs, :cve_code, unique: true
    add_index :medications_catalogs, :name
  end
end
