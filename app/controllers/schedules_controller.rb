class SchedulesController < ApplicationController
  def show
    authorize Job, :update?

    @date = (Date.parse(params[:date]) rescue nil) || Time.zone.today
    @technicians = User.technicians
    jobs = Job.on_day(@date).where.not(status: :canceled).includes(:customer, :property).by_schedule
    @jobs_by_tech = jobs.group_by(&:technician_id)
    @unscheduled = Job.unscheduled.includes(:customer, :property).newest_first.limit(20)
  end
end
