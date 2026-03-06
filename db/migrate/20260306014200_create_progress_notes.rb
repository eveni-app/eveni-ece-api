class CreateProgressNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :progress_notes, id: :uuid, default: "gen_random_uuid()" do |t|
      t.references :patient, null: false, foreign_key: true, type: :uuid
      t.references :doctor,  null: false, foreign_key: true, type: :uuid

      # Signos vitales en JSONB (NOM-004 exploración física)
      t.jsonb :vital_signs, null: false, default: {}

      # Nota de evolución cifrada (ActiveRecord::Encryption)
      t.text :evolution

      # Diagnósticos referenciando CIE-10 (NOM-024 interoperabilidad)
      t.jsonb :diagnoses, null: false, default: []

      t.text :prognosis
      t.text :treatment_plan
      t.string :note_type, null: false, default: "evolution"  # evolution, urgency, interconsultation

      # Logidze audit column (NOM-024 inmutabilidad)
      t.jsonb :log_data

      # Legal Hold (NOM-004 retención 5 años)
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :progress_notes, :discarded_at
    add_index :progress_notes, :note_type
  end
end
