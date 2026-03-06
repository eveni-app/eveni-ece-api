FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { "Eveni2024!" }
    password_confirmation { "Eveni2024!" }
    role { :doctor }

    trait :admin do
      role { :admin }
    end

    trait :doctor do
      role { :doctor }
    end

    trait :nurse do
      role { :nurse }
    end

    trait :receptionist do
      role { :receptionist }
    end
  end
end
