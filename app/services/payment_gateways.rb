module PaymentGateways
  module_function

  # Stripe when a key is configured (use a sk_test_ key for demos), otherwise
  # the built-in simulated checkout.
  def current
    if ENV["STRIPE_SECRET_KEY"].present?
      Stripe.new(api_key: ENV.fetch("STRIPE_SECRET_KEY"))
    else
      Simulated.new
    end
  end
end
