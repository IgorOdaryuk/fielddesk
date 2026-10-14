class AuditLogPolicy < ApplicationPolicy
  def index? = admin?

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.none
    end
  end
end
