class MedicationsCatalog < ApplicationRecord
  validates :cve_code, :name, presence: true
  validates :cve_code, uniqueness: true
end
