class CluesEstablishment < ApplicationRecord
  validates :clues_code, :name, presence: true
  validates :clues_code, uniqueness: true
end
