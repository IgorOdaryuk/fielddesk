require "test_helper"

class MessagingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "on my way text goes out when the technician leaves" do
    job = jobs(:tina_today)

    perform_enqueued_jobs do
      job.transition_to!(:en_route, by: users(:tech))
    end

    message = job.outbound_messages.last
    assert_equal "on_my_way", message.kind
    assert_equal "+18135550101", message.to
    assert message.simulated?, "demo and test environments must never send real SMS"
    assert_includes message.body, "Tina is on the way"
  end

  test "review request is scheduled after completion, once" do
    job = jobs(:tina_today)
    %w[en_route in_progress completed].each { job.transition_to!(_1, by: users(:tech)) }

    review = job.outbound_messages.find_by!(kind: "review_request")
    assert review.scheduled?
    assert_in_delta Company.review_request_delay.from_now, review.send_at, 5

    job.transition_to!(:in_progress, by: users(:dispatcher))
    job.transition_to!(:completed, by: users(:dispatcher))
    assert_equal 1, job.outbound_messages.where(kind: "review_request").count
  end

  test "a review request for a canceled job is skipped" do
    message = Messaging.notify(:review_request, job: jobs(:waiting))
    jobs(:waiting).update!(status: :canceled, cancel_reason: "Customer changed their mind")

    DeliverMessageJob.perform_now(message)
    assert message.reload.skipped?
  end

  test "phone numbers in the outbox are encrypted" do
    message = Messaging.notify(:on_my_way, job: jobs(:tina_today))
    raw = OutboundMessage.connection.select_value(%(SELECT "to" FROM outbound_messages WHERE id = #{message.id}))
    assert_not_includes raw, "5550101"
  end

  test "real SMS needs Twilio config and demo mode off" do
    assert_instance_of SmsProviders::Simulated, SmsProviders.current
  end
end
