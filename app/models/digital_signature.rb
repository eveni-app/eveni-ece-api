class DigitalSignature < ApplicationRecord
  belongs_to :signable, polymorphic: true
  belongs_to :doctor

  validates :signature_payload, :signed_at, presence: true
end
