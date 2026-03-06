class ProgressNote < ApplicationRecord
  include Discard::Model
  has_logidze

  belongs_to :patient
  belongs_to :doctor
  has_one :prescription, dependent: :destroy
  has_many :digital_signatures, as: :signable, dependent: :restrict_with_error

  # Cifrado de la nota de evolución (NOM-024 confidencialidad)
  encrypts :evolution

  enum :note_type, {
    evolution: "evolution",
    urgency: "urgency",
    interconsultation: "interconsultation",
    admission: "admission",
    discharge: "discharge"
  }

  validates :patient, :doctor, :note_type, presence: true
end
