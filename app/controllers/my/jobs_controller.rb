# The technician's own cabinet: a phone-first view of their day.
class My::JobsController < ApplicationController
  def index
    authorize Job
    mine = policy_scope(Job).for_technician(current_user).includes(:customer, :property)
    today = Time.zone.today
    @today = mine.on_day(today).where.not(status: :canceled).by_schedule
    @upcoming = mine.between(today.tomorrow.beginning_of_day..(today + 7).end_of_day).where.not(status: :canceled).by_schedule
    @recent = mine.completed.order(completed_at: :desc).limit(10)
  end

  def show
    @job = authorize Job.find(params[:id])
    @note = JobNote.new
  end
end
