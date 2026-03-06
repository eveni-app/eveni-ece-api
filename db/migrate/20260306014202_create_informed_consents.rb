class CreateInformedConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :informed_consents, id: :uuid, default: "gen_random_uuid()" do |t|
      t.references :patient, null: false, foreign_key: true, type: :uuid
      t.references :doctor,  null: false, foreign_key: true, type: :uuid

      t.string :procedure_name, null: false
      t.text :risks,    null: false
      t.text :benefits, null: false
      t.boolean :patient_accepted, null: false, default: false
      t.datetime :accepted_at

      # Logidze audit column (NOM-024)
      t.jsonb :log_data

      # Legal Hold (NOM-004 retención 5 años)
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :informed_consents, :discarded_at
  end
end
