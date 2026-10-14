require "test_helper"

class ScheduleBoardTest < ActionDispatch::IntegrationTest
  setup do
    @job = jobs(:tina_today)
    @ten = Time.zone.today.in_time_zone.change(hour: 10)
  end

  def reschedule(job, technician:, at:)
    patch reschedule_job_path(job), params: { technician_id: technician.id, scheduled_at: at.iso8601 }, as: :json
  end

  test "board renders draggable jobs and subscribes to live updates" do
    sign_in_as users(:dispatcher)
    get schedule_path
    assert_response :success
    assert_select "[data-controller=schedule]"
    assert_select "a[draggable=true][data-job-id='#{@job.id}']"
    assert_select "turbo-cable-stream-source"
  end

  test "dispatcher drags a job to another technician and time" do
    sign_in_as users(:dispatcher)
    reschedule(@job, technician: users(:other_tech), at: @ten.change(hour: 15, min: 30))

    assert_response :success
    @job.reload
    assert_equal users(:other_tech), @job.technician
    assert_equal "3:30 pm", @job.scheduled_at.strftime("%-l:%M %P")
    assert_includes response.parsed_body["message"], "Otto"
  end

  test "dropping a waiting job onto the board schedules it" do
    sign_in_as users(:dispatcher)
    reschedule(jobs(:waiting), technician: users(:tech), at: @ten.change(hour: 14))

    assert_response :success
    assert jobs(:waiting).reload.scheduled?
  end

  test "double-booking a technician is refused" do
    sign_in_as users(:dispatcher)
    # otto_today is 12:00-14:00 for Otto.
    reschedule(@job, technician: users(:other_tech), at: @ten.change(hour: 13))

    assert_response :unprocessable_content
    assert_equal "Otto is already booked: J-90002 12:00 pm–2:00 pm", response.parsed_body["error"]
    assert_equal users(:tech), @job.reload.technician
  end

  test "back-to-back jobs are fine" do
    sign_in_as users(:dispatcher)
    reschedule(@job, technician: users(:other_tech), at: @ten.change(hour: 14))
    assert_response :success
  end

  test "jobs already under way can't be moved" do
    @job.update!(status: :en_route)
    sign_in_as users(:dispatcher)
    reschedule(@job, technician: users(:other_tech), at: @ten.change(hour: 16))

    assert_response :unprocessable_content
    assert_equal users(:tech), @job.reload.technician
  end

  test "technicians can't move jobs" do
    sign_in_as users(:tech)
    reschedule(@job, technician: users(:tech), at: @ten.change(hour: 16))
    assert_equal 10, @job.reload.scheduled_at.hour
  end

  test "any change to a job tells open boards to refresh" do
    assert_turbo_stream_broadcasts([ accounts(:sunshine), :dispatch ]) do
      @job.update!(problem: "Still won't drain")
      perform_enqueued_jobs
    end
  end
end
