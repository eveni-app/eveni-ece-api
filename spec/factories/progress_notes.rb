FactoryBot.define do
  factory :progress_note do
    association :patient
    association :doctor
    note_type  { "evolution" }
    evolution  { Faker::Lorem.paragraph }
    prognosis  { "Favorable" }
    vital_signs do
      {
        "heart_rate" => 72,
        "blood_pressure_systolic" => 120,
        "blood_pressure_diastolic" => 80,
        "temperature" => 36.5,
        "oxygen_saturation" => 98
      }
    end
    diagnoses { [] }
  end
end
