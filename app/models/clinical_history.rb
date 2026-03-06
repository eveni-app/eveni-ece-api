class ClinicalHistory < ApplicationRecord
  include Discard::Model
  has_logidze

  belongs_to :patient

  validates :patient_id, presence: true
end
