# Política de acceso a pacientes (RBAC NOM-024)
# admin, doctor, nurse → acceso completo a lectura
# receptionist → puede crear y ver datos demográficos pero NO notas clínicas
class PatientPolicy < ApplicationPolicy
  def index?   = clinical_staff?
  def show?    = clinical_staff?
  def create?  = admin_or_doctor? || user.receptionist?
  def update?  = admin_or_doctor?

  class Scope < Scope
    def resolve
      return scope.all if user.admin? || user.doctor? || user.nurse?
      scope.all if user.receptionist?
    end
  end

  private

  def clinical_staff?
    user.admin? || user.doctor? || user.nurse? || user.receptionist?
  end

  def admin_or_doctor?
    user.admin? || user.doctor?
  end
end
