class CreatePrescriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :prescriptions, id: :uuid, default: "gen_random_uuid()" do |t|
      t.references :progress_note, null: false, foreign_key: true, type: :uuid

      # Array de medicamentos referenciando el catálogo CSG (NOM-024)
      t.jsonb :medications, null: false, default: []
      t.text :instructions

      # Logidze audit column (NOM-024)
      t.jsonb :log_data

      # Legal Hold
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :prescriptions, :discarded_at
  end
end
