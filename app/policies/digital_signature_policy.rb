class DigitalSignaturePolicy < ApplicationPolicy
  def index?  = user.admin? || user.doctor?
  def create? = user.doctor?
end
