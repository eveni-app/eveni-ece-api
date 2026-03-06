class Patient < ApplicationRecord
  include Discard::Model

  # ActiveRecord::Encryption (LFPDPPP — datos personales sensibles)
  encrypts :first_name, :last_name
  encrypts :curp, deterministic: true  # deterministic para permitir búsquedas

  enum :sex, { male: 0, female: 1, non_binary: 2 }

  has_one :clinical_history, dependent: :destroy
  has_many :progress_notes, dependent: :restrict_with_error
  has_many :informed_consents, dependent: :restrict_with_error

  validates :curp, presence: true, uniqueness: true, curp: true
  validates :first_name, :last_name, :dob, :sex, presence: true
end
