require "test_helper"

class AccessControlTest < ActionDispatch::IntegrationTest
  test "signed-out visitors are sent to sign in" do
    get jobs_path
    assert_redirected_to new_session_path
  end

  test "staff land on the dashboard, technicians on their cabinet" do
    sign_in_as users(:dispatcher)
    get root_path
    assert_redirected_to dashboard_path

    sign_in_as users(:tech)
    get root_path
    assert_redirected_to my_jobs_path
  end

  test "technicians cannot open the office screens" do
    sign_in_as users(:tech)

    [ dashboard_path, customers_path, schedule_path, users_path, audit_logs_path, new_job_path ].each do |path|
      get path
      assert_response :redirect, "expected #{path} to be blocked"
      assert_equal "You don't have access to that.", flash[:alert]
    end
    assert AuditLog.where(action: "access.denied", user: users(:tech)).exists?
  end

  test "technicians only see their own jobs" do
    sign_in_as users(:tech)

    get my_jobs_path
    assert_response :success
    assert_select "a[href=?]", my_job_path(jobs(:tina_today))
    assert_select "a[href=?]", my_job_path(jobs(:otto_today)), count: 0

    get my_job_path(jobs(:otto_today))
    assert_response :redirect

    get jobs_path
    assert_response :success
    assert_select "td", text: /J-90002/, count: 0
  end

  test "dispatchers cannot manage the team or read the audit log" do
    sign_in_as users(:dispatcher)
    get users_path
    assert_response :redirect
    get audit_logs_path
    assert_response :redirect
  end

  test "admins can read the audit log" do
    sign_in_as users(:admin)
    get audit_logs_path
    assert_response :success
  end
end
