FactoryBot.define do
  factory :author do
    name      { Faker::Name.name }
    specialty { %w[books movies plays].sample }
  end
end
