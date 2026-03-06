class InformedConsent < ApplicationRecord
  include Discard::Model
  has_logidze

  belongs_to :patient
  belongs_to :doctor
  has_many :digital_signatures, as: :signable, dependent: :restrict_with_error

  validates :procedure_name, :risks, :benefits, presence: true
end
