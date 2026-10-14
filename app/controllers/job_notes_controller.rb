class JobNotesController < ApplicationController
  def create
    @job = Job.find(params[:job_id])
    authorize @job, :add_note?

    note = @job.notes.build(body: params.dig(:job_note, :body), user: current_user)
    if note.save
      redirect_back_or_to @job, notice: "Note added."
    else
      redirect_back_or_to @job, alert: note.errors.full_messages.to_sentence
    end
  end
end
