class PropertyPolicy < ApplicationPolicy
  def create?  = staff?
  def update?  = staff?
  def destroy? = staff? && record.jobs.none?
end
