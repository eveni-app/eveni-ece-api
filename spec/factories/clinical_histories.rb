FactoryBot.define do
  factory :clinical_history do
    association :patient
    hereditary_history     { { "diabetes" => false, "hypertension" => true } }
    pathological_history   { { "surgeries" => [], "allergies" => ["penicillin"] } }
    non_pathological_history { { "smoking" => false, "alcohol" => false } }
    gynecological_history  { {} }
  end
end
