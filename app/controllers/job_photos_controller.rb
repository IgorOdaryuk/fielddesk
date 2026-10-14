class JobPhotosController < ApplicationController
  def create
    @job = Job.find(params[:job_id])
    authorize @job, :add_photos?

    files = Array(params[:photos]).compact_blank
    return redirect_back_or_to(@job, alert: "Choose at least one photo.") if files.empty?

    @job.photos.attach(files)
    if @job.valid?
      AuditLog.record(action: "job.photos_added", auditable: @job, changes: { "count" => [ nil, files.size ] })
      redirect_back_or_to @job, notice: "#{files.size} photo(s) uploaded."
    else
      @job.photos.last(files.size).each(&:purge)
      redirect_back_or_to @job, alert: @job.errors.full_messages.to_sentence
    end
  end
end
