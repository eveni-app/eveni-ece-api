FactoryBot.define do
  factory :doctor do
    association :user, :doctor
    professional_license { Faker::Alphanumeric.unique.alphanumeric(number: 8).upcase }
    specialty { Faker::Lorem.word }
    public_certificate { nil }
  end
end
