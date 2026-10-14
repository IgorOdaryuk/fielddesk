class DashboardsController < ApplicationController
  def show
    authorize :dashboard

    today = Time.zone.today
    @today_jobs = Job.on_day(today).includes(:customer, :technician).by_schedule
    @unscheduled = Job.unscheduled.includes(:customer).newest_first.limit(10)
    @counts = {
      today: @today_jobs.count,
      in_field: Job.where(status: %i[en_route in_progress]).count,
      unscheduled: Job.unscheduled.count,
      completed_week: Job.completed.where(completed_at: today.beginning_of_week.in_time_zone..).count
    }
    @technicians = User.technicians
    @tech_load = @today_jobs.reorder(nil).where.not(technician_id: nil).group(:technician_id).count
    @sources = Job.where(created_at: 30.days.ago..).group(:source).count.sort_by { -_2 }
  end
end
