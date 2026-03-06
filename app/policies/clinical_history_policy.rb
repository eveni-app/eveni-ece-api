class ClinicalHistoryPolicy < ApplicationPolicy
  def show?   = user.admin? || user.doctor? || user.nurse?
  def create? = user.admin? || user.doctor?
  def update? = user.admin? || user.doctor?
end
