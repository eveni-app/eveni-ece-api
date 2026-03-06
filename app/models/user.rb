class User < ApplicationRecord
  include Discard::Model

  # RBAC roles (NOM-024)
  enum :role, { admin: 0, doctor: 1, nurse: 2, receptionist: 3 }

  # Devise with JWT (JTIMatcher strategy for session revocation)
  devise :database_authenticatable, :registerable,
         :recoverable, :validatable, :jwt_authenticatable,
         jwt_revocation_strategy: self

  # JTI Matcher — revocation via jti column
  include Devise::JWT::RevocationStrategies::JTIMatcher

  has_one :doctor, dependent: :destroy

  validates :role, presence: true

  # Inicializar JTI con UUID al crear el usuario (requerido por JTIMatcher)
  before_create :set_jti

  private

  def set_jti
    self.jti ||= SecureRandom.uuid
  end
end
