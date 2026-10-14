class DeliverMessageJob < ApplicationJob
  queue_as :default
  retry_on SmsProviders::Twilio::Error, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.arguments.first.update!(status: :failed, error: error.message.truncate(250))
  end

  def perform(message)
    return unless message.scheduled?
    # A job canceled before its review request goes out shouldn't ask for a review.
    return message.update!(status: :skipped, error: "Job was canceled") if message.job&.canceled?

    provider = SmsProviders.current
    result = provider.deliver(message)
    message.update!(status: result[:status], provider: provider.name, provider_id: result[:provider_id], sent_at: Time.current)
  end
end
