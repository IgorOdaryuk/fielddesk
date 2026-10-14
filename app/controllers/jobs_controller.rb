class JobsController < ApplicationController
  before_action :set_job, only: %i[ show edit update destroy transition ]

  def index
    authorize Job
    scope = policy_scope(Job).search(params[:q]).includes(:customer, :technician, :property)
    scope = scope.where(status: params[:status]) if Job.statuses.key?(params[:status])
    scope = scope.where(technician_id: params[:technician_id]) if params[:technician_id].present?
    @pagy, @jobs = pagy(:offset, scope.newest_first, limit: 25)
    @technicians = User.technicians
  end

  def show
    @note = JobNote.new
    @history = AuditLog.where(auditable: @job).includes(:user).recent.limit(30)
  end

  # Booking starts from a customer; without one, show a picker first.
  def new
    customer = Customer.find_by(id: params[:customer_id])
    @job = authorize Job.new(customer: customer, property: customer&.properties&.first, source: customer&.source)
    return if customer

    @customers = Customer.search(params[:q]).alphabetical.limit(params[:q].present? ? 20 : 0)
    render :pick_customer
  end

  def create
    @job = authorize Job.new(job_params.merge(created_by: current_user))
    @job.status = :scheduled if @job.unscheduled? && @job.scheduled_at.present? && @job.technician.present?

    if @job.save
      redirect_to @job, notice: "Job #{@job.number} created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @job.update(job_params)
      redirect_to @job, notice: "Job updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @job.destroy!
    redirect_to jobs_path, notice: "Job deleted.", status: :see_other
  end

  def transition
    @job.transition_to!(params.require(:status), by: current_user, cancel_reason: params[:cancel_reason])
    redirect_back_or_to @job, notice: "#{@job.number} is now #{@job.status.humanize.downcase}."
  rescue ActiveRecord::RecordInvalid
    redirect_back_or_to @job, alert: @job.errors.full_messages.to_sentence
  end

  private
    def set_job
      @job = authorize Job.find(params[:id])
    end

    def job_params
      params.expect(job: [ :customer_id, :property_id, :technician_id, :appliance, :brand, :model_number,
                           :problem, :source, :priority, :scheduled_at, :duration_minutes ])
    end
end
