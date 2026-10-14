module PaymentGateways
  # Stripe Checkout: we create a hosted payment page for the balance due and
  # mark the invoice paid when Stripe calls our webhook.
  class Stripe
    def initialize(api_key:)
      @api_key = api_key
    end

    def name = "stripe"
    def simulated? = false

    def checkout_url(invoice, success_url:, cancel_url:)
      session = ::Stripe::Checkout::Session.create({
        mode: "payment",
        client_reference_id: invoice.id.to_s,
        metadata: { invoice_id: invoice.id },
        line_items: [ {
          quantity: 1,
          price_data: { currency: "usd", unit_amount: invoice.balance_cents,
                        product_data: { name: "#{Company.name} · invoice #{invoice.number}" } }
        } ],
        success_url: success_url,
        cancel_url: cancel_url
      }, { api_key: @api_key })
      session.url
    end

    def self.parse_webhook(payload, signature)
      ::Stripe::Webhook.construct_event(payload, signature, ENV.fetch("STRIPE_WEBHOOK_SECRET"))
    end
  end
end
