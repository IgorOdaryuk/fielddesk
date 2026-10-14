module SmsProviders
  module_function

  # Real SMS only when Twilio is configured AND the app is not in demo mode.
  def current
    if !Demo.enabled? && ENV["TWILIO_ACCOUNT_SID"].present?
      Twilio.new(account_sid: ENV.fetch("TWILIO_ACCOUNT_SID"), auth_token: ENV.fetch("TWILIO_AUTH_TOKEN"), from: ENV.fetch("TWILIO_FROM_NUMBER"))
    else
      Simulated.new
    end
  end
end
