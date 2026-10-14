class UserPolicy < ApplicationPolicy
  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  # Admins deactivate people instead of deleting them, so history keeps its authors.
  def deactivate? = admin? && record != user

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.none
    end
  end
end
