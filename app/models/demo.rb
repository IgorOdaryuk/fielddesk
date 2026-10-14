# Demo mode: fictional data, no real SMS, simulated or test-mode payments.
# Always on in development; opt in elsewhere with DEMO_MODE=1.
module Demo
  module_function

  def enabled?
    Rails.env.development? || ENV["DEMO_MODE"].present?
  end
end
