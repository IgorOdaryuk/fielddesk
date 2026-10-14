module SmsProviders
  # Keeps the message inside the app. Used in demo mode and in tests.
  class Simulated
    def name = "simulated"

    def deliver(_message)
      { status: :simulated, provider_id: "sim_#{SecureRandom.hex(6)}" }
    end
  end
end
