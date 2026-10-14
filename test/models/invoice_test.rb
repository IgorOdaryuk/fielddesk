require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @job = jobs(:tina_today)
    @invoice = Invoice.open_for!(@job)
  end

  test "opening an invoice uses company tax and payment terms, once per job" do
    assert_equal Company.tax_rate_bps, @invoice.tax_rate_bps
    assert_equal Date.current + Company.payment_terms_days, @invoice.due_on
    assert_match(/\AINV-\d+\z/, @invoice.reload.number)
    assert_equal @invoice, Invoice.open_for!(@job)
    assert @invoice.payment_token.length >= 24
  end

  test "totals tax parts but not labor" do
    @invoice.items.create!(kind: :labor, description: "Labor", quantity: 1.5, unit_price: "95.00")
    @invoice.items.create!(kind: :part, description: "Drain pump", quantity: 1, unit_price: "$79.00")
    @invoice.reload

    assert_equal 14_250 + 7_900, @invoice.subtotal_cents
    assert_equal 593, @invoice.tax_cents # 7.5% of $79.00 = $5.925
    assert_equal 22_743, @invoice.total_cents
  end

  test "sending texts the customer a pay link" do
    @invoice.items.create!(kind: :fee, description: "Visit", unit_price: "89")

    assert_difference -> { OutboundMessage.where(kind: "invoice").count } do
      @invoice.reload.send_to_customer!
    end
    assert @invoice.sent?
    assert_includes OutboundMessage.last.body, "/pay/#{@invoice.payment_token}"
  end

  test "an empty invoice can't be sent" do
    assert_raises(ArgumentError) { @invoice.send_to_customer! }
  end

  test "partial then full payment, with a receipt each time" do
    invoice = invoices(:bob_sent)

    invoice.record_payment!(amount_cents: 10_000, method: :cash, by: users(:tech))
    assert invoice.sent?
    assert_equal 9_650, invoice.balance_cents

    invoice.record_payment!(amount_cents: 9_650, method: :check, reference: "1042")
    assert invoice.paid?
    assert_not_nil invoice.paid_at
    assert_equal 2, OutboundMessage.where(kind: "receipt").count
  end

  test "overpayment is refused" do
    assert_raises(ActiveRecord::RecordInvalid) do
      invoices(:bob_sent).record_payment!(amount_cents: 99_999, method: :cash)
    end
  end

  test "the same gateway charge is recorded once" do
    invoice = invoices(:bob_sent)
    2.times { invoice.record_payment!(amount_cents: 19_650, method: :online, gateway: "stripe", gateway_id: "cs_test_1") }
    assert_equal 1, invoice.payments.count
  end

  test "lines are locked once money has been taken" do
    invoice = invoices(:bob_sent)
    invoice.record_payment!(amount_cents: 5_000, method: :cash)

    item = invoice.items.build(kind: :fee, description: "Late fee", unit_price: "10")
    assert_not item.save
  end

  test "paid invoices can't be voided" do
    invoice = invoices(:bob_sent)
    invoice.record_payment!(amount_cents: 19_650, method: :cash)
    assert_raises(ArgumentError) { invoice.void! }
  end

  test "renders a PDF" do
    pdf = InvoicePdf.new(invoices(:bob_sent)).render
    assert pdf.start_with?("%PDF")
  end
end
