class CreateClinicalHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :clinical_histories, id: :uuid, default: "gen_random_uuid()" do |t|
      t.references :patient, null: false, foreign_key: true, type: :uuid

      # JSONB para flexibilidad de antecedentes (NOM-004)
      t.jsonb :hereditary_history,     null: false, default: {}
      t.jsonb :pathological_history,   null: false, default: {}
      t.jsonb :non_pathological_history, null: false, default: {}
      t.jsonb :gynecological_history,  null: false, default: {}

      # Logidze audit column (NOM-024 inmutabilidad)
      t.jsonb :log_data

      # Legal Hold (NOM-004 retención 5 años)
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :clinical_histories, :discarded_at
  end
end
