class DashboardPolicy < ApplicationPolicy
  def show? = staff?
end
