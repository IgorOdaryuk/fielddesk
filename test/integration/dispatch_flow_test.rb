require "test_helper"

class DispatchFlowTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:dispatcher) }

  test "every office page renders" do
    [ dashboard_path, schedule_path, schedule_path(date: Date.tomorrow), jobs_path, jobs_path(status: "scheduled", q: "LG"),
      customers_path, customers_path(q: "jane"), customer_path(customers(:jane)), job_path(jobs(:tina_today)),
      new_job_path, new_job_path(q: "bob"), new_job_path(customer_id: customers(:jane).id), edit_job_path(jobs(:tina_today)),
      new_customer_path, edit_customer_path(customers(:jane)), new_customer_property_path(customers(:jane)) ].each do |path|
      get path
      assert_response :success, "#{path} failed"
    end
  end

  test "dispatcher books a new customer and a scheduled job" do
    post customers_path, params: { customer: {
      name: "Carla Gomez", phone: "(813) 555-0150", source: "lsa",
      properties_attributes: [ { street: "9 Oak St", city: "Tampa", state: "fl", zip: "33604" } ]
    } }
    customer = Customer.find_by!(name: "Carla Gomez")
    assert_redirected_to customer_path(customer)
    assert_equal "FL", customer.properties.first.state

    post jobs_path, params: { job: {
      customer_id: customer.id, property_id: customer.properties.first.id, appliance: "Dishwasher",
      problem: "Not draining", technician_id: users(:tech).id, scheduled_at: 1.day.from_now.change(hour: 9), duration_minutes: 120
    } }
    job = customer.jobs.last
    assert_redirected_to job_path(job)
    assert job.scheduled?
    assert_equal users(:dispatcher), job.created_by
  end

  test "dispatcher cancels a job with a reason" do
    patch transition_job_path(jobs(:waiting)), params: { status: "canceled", cancel_reason: "Customer fixed it" }
    assert jobs(:waiting).reload.canceled?
  end
end
