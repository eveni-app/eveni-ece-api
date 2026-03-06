# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_06_021330) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "hstore"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "uuid-ossp"

  create_table "cie10_diagnoses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category"
    t.string "chapter"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_cie10_diagnoses_on_category"
    t.index ["code"], name: "index_cie10_diagnoses_on_code", unique: true
  end

  create_table "clinical_histories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.jsonb "gynecological_history", default: {}, null: false
    t.jsonb "hereditary_history", default: {}, null: false
    t.jsonb "log_data"
    t.jsonb "non_pathological_history", default: {}, null: false
    t.jsonb "pathological_history", default: {}, null: false
    t.uuid "patient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_clinical_histories_on_discarded_at"
    t.index ["patient_id"], name: "index_clinical_histories_on_patient_id"
  end

  create_table "clues_establishments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "clues_code", null: false
    t.datetime "created_at", null: false
    t.string "institution_type"
    t.string "municipality"
    t.string "name", null: false
    t.string "state_code"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["clues_code"], name: "index_clues_establishments_on_clues_code", unique: true
    t.index ["state_code"], name: "index_clues_establishments_on_state_code"
  end

  create_table "digital_signatures", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "certificate_serial"
    t.datetime "created_at", null: false
    t.uuid "doctor_id", null: false
    t.uuid "signable_id", null: false
    t.string "signable_type", null: false
    t.text "signature_payload", null: false
    t.datetime "signed_at", null: false
    t.datetime "updated_at", null: false
    t.index ["doctor_id"], name: "index_digital_signatures_on_doctor_id"
    t.index ["signable_type", "signable_id"], name: "index_digital_signatures_on_signable"
    t.index ["signed_at"], name: "index_digital_signatures_on_signed_at"
  end

  create_table "doctors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "professional_license", null: false
    t.text "public_certificate"
    t.string "specialty"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["discarded_at"], name: "index_doctors_on_discarded_at"
    t.index ["professional_license"], name: "index_doctors_on_professional_license", unique: true
    t.index ["user_id"], name: "index_doctors_on_user_id"
  end

  create_table "informed_consents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.text "benefits", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.uuid "doctor_id", null: false
    t.jsonb "log_data"
    t.boolean "patient_accepted", default: false, null: false
    t.uuid "patient_id", null: false
    t.string "procedure_name", null: false
    t.text "risks", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_informed_consents_on_discarded_at"
    t.index ["doctor_id"], name: "index_informed_consents_on_doctor_id"
    t.index ["patient_id"], name: "index_informed_consents_on_patient_id"
  end

  create_table "medications_catalogs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "active_ingredient"
    t.datetime "created_at", null: false
    t.string "cve_code", null: false
    t.string "name", null: false
    t.string "presentation"
    t.string "route_of_administration"
    t.datetime "updated_at", null: false
    t.index ["cve_code"], name: "index_medications_catalogs_on_cve_code", unique: true
    t.index ["name"], name: "index_medications_catalogs_on_name"
  end

  create_table "patients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "curp", null: false
    t.datetime "discarded_at"
    t.date "dob", null: false
    t.string "email"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.integer "sex", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["curp"], name: "index_patients_on_curp", unique: true
    t.index ["discarded_at"], name: "index_patients_on_discarded_at"
  end

  create_table "prescriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.text "instructions"
    t.jsonb "log_data"
    t.jsonb "medications", default: [], null: false
    t.uuid "progress_note_id", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_prescriptions_on_discarded_at"
    t.index ["progress_note_id"], name: "index_prescriptions_on_progress_note_id"
  end

  create_table "progress_notes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "diagnoses", default: [], null: false
    t.datetime "discarded_at"
    t.uuid "doctor_id", null: false
    t.text "evolution"
    t.jsonb "log_data"
    t.string "note_type", default: "evolution", null: false
    t.uuid "patient_id", null: false
    t.text "prognosis"
    t.text "treatment_plan"
    t.datetime "updated_at", null: false
    t.jsonb "vital_signs", default: {}, null: false
    t.index ["discarded_at"], name: "index_progress_notes_on_discarded_at"
    t.index ["doctor_id"], name: "index_progress_notes_on_doctor_id"
    t.index ["note_type"], name: "index_progress_notes_on_note_type"
    t.index ["patient_id"], name: "index_progress_notes_on_patient_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "jti", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "clinical_histories", "patients"
  add_foreign_key "digital_signatures", "doctors"
  add_foreign_key "doctors", "users"
  add_foreign_key "informed_consents", "doctors"
  add_foreign_key "informed_consents", "patients"
  add_foreign_key "prescriptions", "progress_notes"
  add_foreign_key "progress_notes", "doctors"
  add_foreign_key "progress_notes", "patients"
end
