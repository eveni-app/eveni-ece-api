class Cie10Diagnosis < ApplicationRecord
  validates :code, :description, presence: true
  validates :code, uniqueness: true
end
