# Payments taken in person: cash, check, or a card swiped on site.
class PaymentsController < ApplicationController
  def create
    invoice = authorize Invoice.find(params[:invoice_id]), :record_payment?
    attrs = params.expect(payment: [ :amount, :method, :reference ])
    method = attrs[:method].presence_in(%w[cash check card_on_site]) || "cash"
    amount_cents = (BigDecimal(attrs[:amount].to_s.delete("$,").presence || "0") * 100).round

    invoice.record_payment!(amount_cents: amount_cents, method: method, by: current_user, reference: attrs[:reference].presence)
    redirect_back_or_to invoice, notice: invoice.reload.paid? ? "Paid in full. Receipt texted to the customer." : "Payment recorded."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_back_or_to invoice, alert: e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.to_sentence : e.message
  end
end
