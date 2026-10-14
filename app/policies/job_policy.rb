class JobPolicy < ApplicationPolicy
  def index?   = true
  def show?    = staff? || own?
  def create?  = staff?
  def update?  = staff?
  def destroy? = admin? && record.unscheduled?

  # Technicians move their own jobs through the field statuses only;
  # Job#allowed_transitions_for holds the exact rules.
  def transition?  = staff? || own?
  def reschedule?  = staff?
  def add_note?    = staff? || own?
  def add_photos?  = staff? || own?

  private
    def own?
      user.technician? && record.technician_id == user.id
    end

  class Scope < Scope
    def resolve
      user.staff? ? scope.all : scope.where(technician: user)
    end
  end
end
