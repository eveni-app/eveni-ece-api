class CreateDigitalSignatures < ActiveRecord::Migration[8.1]
  def change
    create_table :digital_signatures, id: :uuid, default: "gen_random_uuid()" do |t|
      # Polimórfico para asociar a cualquier modelo firmable
      t.references :signable, polymorphic: true, null: false, type: :uuid

      t.references :doctor, null: false, foreign_key: true, type: :uuid

      # PKCS#7 signature encoded in Base64
      t.text :signature_payload, null: false

      # Certificado público del médico (serie o PEM)
      t.text :certificate_serial

      # Sello de tiempo (NOM-024 § firma electrónica avanzada)
      t.datetime :signed_at, null: false

      t.timestamps
    end

    add_index :digital_signatures, :signed_at
  end
end
