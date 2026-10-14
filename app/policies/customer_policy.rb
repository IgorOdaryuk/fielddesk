class CustomerPolicy < ApplicationPolicy
  def index?   = staff?
  def show?    = staff?
  def create?  = staff?
  def update?  = staff?
  def destroy? = admin? && record.jobs.none?

  class Scope < Scope
    def resolve
      user.staff? ? scope.all : scope.none
    end
  end
end
