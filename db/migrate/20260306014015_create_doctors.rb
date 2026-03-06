class CreateDoctors < ActiveRecord::Migration[8.1]
  def change
    create_table :doctors, id: :uuid, default: "gen_random_uuid()" do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :professional_license, null: false
      t.string :specialty
      t.text :public_certificate
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :doctors, :professional_license, unique: true
    add_index :doctors, :discarded_at
  end
end
