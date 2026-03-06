# Política de notas de evolución (NOM-024 — solo personal clínico autorizado)
# El recepcionista NO tiene acceso a notas médicas por privacidad.
class ProgressNotePolicy < ApplicationPolicy
  def index?  = clinical_only?
  def show?   = clinical_only?
  def create? = user.admin? || user.doctor?
  def update? = user.admin? || user.doctor?

  class Scope < Scope
    def resolve
      return scope.all if user.admin? || user.doctor? || user.nurse?
      scope.none
    end
  end

  private

  def clinical_only?
    user.admin? || user.doctor? || user.nurse?
  end
end
