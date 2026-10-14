require "test_helper"

class JobTest < ActiveSupport::TestCase
  test "gets a sequential human-friendly number" do
    job = Job.create!(customer: customers(:bob), property: properties(:bob_home), appliance: "Oven", problem: "No heat")
    assert_match(/\AJ-\d{5,}\z/, job.reload.number)
  end

  test "address must belong to the job's customer" do
    job = Job.new(customer: customers(:jane), property: properties(:bob_home), appliance: "Oven", problem: "x")
    assert_not job.valid?
    assert_includes job.errors[:property], "must belong to the selected customer"
  end

  test "a scheduled job needs a time and a technician" do
    job = jobs(:waiting)
    job.status = :scheduled
    assert_not job.valid?
    assert job.errors.key?(:scheduled_at)
    assert job.errors.key?(:technician)
  end

  test "only active technicians can be assigned" do
    job = jobs(:waiting)
    job.technician = users(:dispatcher)
    assert_not job.valid?

    job.technician = users(:retired)
    assert_not job.valid?
  end

  test "technician drives only the field statuses of their own job" do
    job = jobs(:tina_today)

    assert_equal %w[en_route], job.allowed_transitions_for(users(:tech))
    assert_empty job.allowed_transitions_for(users(:other_tech))
    assert_includes job.allowed_transitions_for(users(:dispatcher)), "canceled"
  end

  test "walking a job through the field stamps start and finish times" do
    job = jobs(:tina_today)
    tech = users(:tech)

    job.transition_to!(:en_route, by: tech)
    job.transition_to!(:in_progress, by: tech)
    assert_not_nil job.started_at

    job.transition_to!(:completed, by: tech)
    assert_not_nil job.completed_at
  end

  test "illegal transitions are refused" do
    job = jobs(:tina_today)
    assert_raises(ActiveRecord::RecordInvalid) { job.transition_to!(:canceled, by: users(:tech)) }
    assert_raises(ActiveRecord::RecordInvalid) { job.transition_to!(:completed, by: users(:dispatcher)) }
    assert job.reload.scheduled?
  end

  test "canceling needs a reason" do
    job = jobs(:waiting)
    assert_raises(ActiveRecord::RecordInvalid) { job.transition_to!(:canceled, by: users(:dispatcher)) }
    job.transition_to!(:canceled, by: users(:dispatcher), cancel_reason: "Customer fixed it")
    assert job.canceled?
  end
end
