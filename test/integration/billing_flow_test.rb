require "test_helper"

class BillingFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "technician invoices on site and takes a card payment" do
    job = jobs(:tina_today)
    job.update!(status: :in_progress)
    sign_in_as users(:tech)

    post job_invoice_path(job)
    invoice = job.reload.invoice
    assert_redirected_to my_job_path(job, anchor: "invoice")

    post invoice_items_path(invoice), params: { invoice_item: { kind: "part", description: "Drain pump", quantity: 1, unit_price: "79" } }
    post invoice_items_path(invoice), params: { invoice_item: { kind: "labor", description: "Labor", quantity: 1, unit_price: "95" } }
    assert_equal 17_993, invoice.reload.total_cents

    post invoice_payments_path(invoice), params: { payment: { amount: "179.93", method: "card_on_site" } }
    assert invoice.reload.paid?
    assert_equal users(:tech), invoice.payments.last.recorded_by
  end

  test "technician cannot touch another technician's invoice" do
    invoice = Invoice.open_for!(jobs(:otto_today))
    sign_in_as users(:tech)

    post invoice_items_path(invoice), params: { invoice_item: { kind: "fee", description: "x", unit_price: "1" } }
    assert_empty invoice.items.reload
  end

  test "office screens render" do
    sign_in_as users(:dispatcher)
    [ invoices_path, invoices_path(status: "outstanding"), invoice_path(invoices(:bob_sent)), outbound_messages_path,
      job_path(jobs(:waiting)) ].each do |path|
      get path
      assert_response :success, path
    end

    get invoice_path(invoices(:bob_sent), format: :pdf)
    assert_equal "application/pdf", response.media_type
  end

  test "dispatcher voids an unpaid invoice" do
    sign_in_as users(:dispatcher)
    post void_invoice_path(invoices(:bob_sent))
    assert invoices(:bob_sent).reload.void?
  end

  test "customer pays by link with the simulated card" do
    invoice = invoices(:bob_sent)

    get pay_path(invoice.payment_token)
    assert_response :success
    assert_select "button", text: /Pay \$196.50/

    post pay_start_path(invoice.payment_token)
    assert_redirected_to pay_checkout_path(invoice.payment_token)

    post pay_checkout_path(invoice.payment_token), params: { card_number: "4000 0000 0000 0002" }
    assert_equal "Your card was declined.", flash[:alert]
    assert invoice.reload.sent?

    post pay_checkout_path(invoice.payment_token), params: { card_number: "4242 4242 4242 4242" }
    assert invoice.reload.paid?
    assert invoice.payments.last.paid_by_online?
  end

  test "pay page hides the full name and refuses unknown or draft tokens" do
    get pay_path(invoices(:bob_sent).payment_token)
    assert_select "body", text: /Bob/
    assert_select "body", text: /Smith/, count: 0

    get pay_path("not-a-real-token")
    assert_response :not_found

    draft = Invoice.open_for!(jobs(:tina_today))
    get pay_path(draft.payment_token)
    assert_response :not_found
  end

  test "stripe webhook rejects unsigned payloads" do
    ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_test"
    post "/webhooks/stripe", params: { type: "checkout.session.completed" }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :bad_request
  ensure
    ENV.delete("STRIPE_WEBHOOK_SECRET")
  end

  test "signed stripe webhook marks the invoice paid" do
    invoice = invoices(:bob_sent)
    secret = "whsec_test"
    payload = {
      id: "evt_1", object: "event", type: "checkout.session.completed",
      data: { object: { id: "cs_test_123", object: "checkout.session", payment_status: "paid", amount_total: 19_650,
                        metadata: { invoice_id: invoice.id.to_s } } }
    }.to_json
    timestamp = Time.now.to_i
    signature = Stripe::Webhook::Signature.compute_signature(Time.at(timestamp), payload, secret)

    ENV["STRIPE_WEBHOOK_SECRET"] = secret
    post "/webhooks/stripe", params: payload, headers: { "Content-Type" => "application/json", "Stripe-Signature" => "t=#{timestamp},v1=#{signature}" }

    assert_response :ok
    assert invoice.reload.paid?
    assert_equal "cs_test_123", invoice.payments.last.gateway_id
  ensure
    ENV.delete("STRIPE_WEBHOOK_SECRET")
  end
end
