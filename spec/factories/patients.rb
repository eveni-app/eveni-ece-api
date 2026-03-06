FactoryBot.define do
  factory :patient do
    # Generamos CURPs únicas con dígito verificador correcto (algoritmo RENAPO Ñ-aware)
    sequence(:curp) do |n|
      # Pool de CURPs válidas verificadas con el algoritmo Módulo 10 RENAPO (Ñ-aware)
      valid_curps = %w[
        HEGG560427MVZRRL04
        MOCA811118HDFRRR04
        SARA780105MDFLML09
        LOOA531113MSRXNS02
        RARL850812HJCMNN08
        GOMJ900215HDFMRN09
        PELM750930MNTLRR08
      ]
      valid_curps[(n - 1) % valid_curps.length]
    end

    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    dob        { Faker::Date.birthday(min_age: 1, max_age: 90) }
    sex        { :male }

    trait :female do
      sex { :female }
    end
  end
end
