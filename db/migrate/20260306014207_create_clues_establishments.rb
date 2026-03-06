class CreateCluesEstablishments < ActiveRecord::Migration[8.1]
  def change
    create_table :clues_establishments, id: :uuid, default: "gen_random_uuid()" do |t|
      t.string :clues_code,  null: false
      t.string :name,        null: false
      t.string :state_code
      t.string :municipality
      t.string :institution_type
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :clues_establishments, :clues_code, unique: true
    add_index :clues_establishments, :state_code
  end
end
