class Prescription < ApplicationRecord
  include Discard::Model
  has_logidze

  belongs_to :progress_note

  validates :progress_note, :medications, presence: true
end
