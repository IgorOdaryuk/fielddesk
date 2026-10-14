class StripeWebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def create
    event = PaymentGateways::Stripe.parse_webhook(request.raw_post, request.headers["Stripe-Signature"])

    if event.type == "checkout.session.completed" && event.data.object.payment_status == "paid"
      session = event.data.object
      invoice = Invoice.find_by(id: session.metadata["invoice_id"])
      invoice&.record_payment!(amount_cents: session.amount_total, method: :online, gateway: "stripe", gateway_id: session.id)
    end

    head :ok
  rescue JSON::ParserError, ::Stripe::SignatureVerificationError
    head :bad_request
  end

  private
    def skip_authorization_check?
      true
    end
end
