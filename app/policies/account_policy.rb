class AccountPolicy < ApplicationPolicy
  def edit? = update?
  def update? = admin? && record == user.account
end
