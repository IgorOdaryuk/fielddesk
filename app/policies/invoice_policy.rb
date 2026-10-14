class InvoicePolicy < ApplicationPolicy
  # Technicians bill on site for their own jobs; voiding stays with the office.
  def index?          = staff?
  def show?           = staff? || own_job?
  def create?         = staff? || own_job?
  def update?         = (staff? || own_job?) && record.editable?
  def send_invoice?   = (staff? || own_job?) && (record.draft? || record.sent?) && record.total_cents.positive?
  def record_payment? = (staff? || own_job?) && (record.draft? || record.sent?) && record.balance_cents.positive?
  def void?           = staff? && !record.paid? && record.payments.none? && !record.void?

  private
    def own_job?
      user.technician? && record.job.technician_id == user.id
    end

  class Scope < Scope
    def resolve
      user.staff? ? scope.all : scope.joins(:job).where(jobs: { technician_id: user.id })
    end
  end
end
