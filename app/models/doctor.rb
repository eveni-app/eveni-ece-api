class Doctor < ApplicationRecord
  include Discard::Model

  belongs_to :user
  has_many :progress_notes, dependent: :restrict_with_error
  has_many :informed_consents, dependent: :restrict_with_error
  has_many :digital_signatures, dependent: :restrict_with_error

  validates :professional_license, presence: true, uniqueness: true
end
