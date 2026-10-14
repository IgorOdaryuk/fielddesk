module PaymentGateways
  # A stand-in for a card processor so the full pay-by-link flow works with no
  # third-party account. Test cards mirror Stripe's: 4242… pays, 4000…0002 declines.
  class Simulated
    APPROVED_CARD = "4242424242424242".freeze
    DECLINED_CARD = "4000000000000002".freeze

    def name = "simulated"
    def simulated? = true

    def checkout_url(invoice, **)
      Rails.application.routes.url_helpers.pay_checkout_path(invoice.payment_token)
    end

    def charge(card_number)
      digits = card_number.to_s.gsub(/\D/, "")
      return { ok: true, id: "sim_ch_#{SecureRandom.hex(8)}" } if digits == APPROVED_CARD

      { ok: false, error: digits == DECLINED_CARD ? "Your card was declined." : "Use the test card 4242 4242 4242 4242." }
    end
  end
end
