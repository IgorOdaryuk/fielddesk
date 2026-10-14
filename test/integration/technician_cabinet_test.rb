require "test_helper"

class TechnicianCabinetTest < ActionDispatch::IntegrationTest
  setup do
    @job = jobs(:tina_today)
    sign_in_as users(:tech)
  end

  test "technician works a job from arrival to completion" do
    get my_job_path(@job)
    assert_response :success
    assert_select "button", text: "On my way"

    %w[en_route in_progress completed].each do |status|
      patch transition_job_path(@job, status: status)
      assert_equal status, @job.reload.status
    end

    actions = AuditLog.where(auditable: @job, user: users(:tech)).pluck(:action)
    assert_equal 3, actions.count("job.update")
  end

  test "technician cannot move someone else's job" do
    patch transition_job_path(jobs(:otto_today), status: "en_route")
    assert jobs(:otto_today).reload.scheduled?
  end

  test "technician adds notes and photos to their job" do
    assert_difference -> { @job.notes.count } do
      post job_notes_path(@job), params: { job_note: { body: "Replaced the pump" } }
    end

    photo = fixture_file_upload("washer.png", "image/png")
    post job_photos_path(@job), params: { photos: [ photo ] }
    assert_equal 1, @job.reload.photos.count
  end

  test "non-image uploads are rejected" do
    file = fixture_file_upload("notes.txt", "text/plain")
    post job_photos_path(@job), params: { photos: [ file ] }
    assert_equal 0, @job.reload.photos.count
  end
end
