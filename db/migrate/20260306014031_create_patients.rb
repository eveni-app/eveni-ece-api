class CreatePatients < ActiveRecord::Migration[8.1]
  def change
    create_table :patients, id: :uuid, default: "gen_random_uuid()" do |t|
      # Encrypted columns (ActiveRecord::Encryption) — stored as ciphertext
      t.string :curp,       null: false  # deterministic encryption for searches
      t.string :first_name, null: false
      t.string :last_name,  null: false
      t.date   :dob,        null: false
      t.integer :sex,       null: false, default: 0  # 0=male, 1=female, 2=non_binary
      t.string  :email
      t.string  :phone

      # Legal Hold / Soft Delete (LFPDPPP + NOM-004)
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :patients, :curp, unique: true
    add_index :patients, :discarded_at
  end
end
