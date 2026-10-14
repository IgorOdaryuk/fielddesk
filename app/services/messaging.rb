# Customer notifications. Builds the text, stores it as an OutboundMessage and
# hands delivery to a background job, so a slow SMS provider never blocks a
# technician tapping "On my way".
module Messaging
  module_function

  def notify(kind, job:, send_at: Time.current, **context)
    customer = job.customer
    return if customer.phone.blank?
    return if kind == :review_request && job.outbound_messages.exists?(kind: "review_request")

    message = OutboundMessage.create!(
      kind: kind.to_s, customer: customer, job: job, to: customer.phone, send_at: send_at,
      body: body_for(kind, job: job, customer: customer, **context)
    )
    DeliverMessageJob.set(wait_until: send_at).perform_later(message)
    message
  end

  def body_for(kind, job:, customer:, invoice: nil, payment: nil)
    tech = job.technician&.first_name || "Your technician"
    money = ->(cents) { ActiveSupport::NumberHelper.number_to_currency(cents / 100.0) }

    case kind
    when :on_my_way
      "Hi #{customer.first_name}, it's #{Company.name}. #{tech} is on the way for your #{job.appliance.downcase} repair and should arrive in about 30 minutes."
    when :booking_confirmation
      "Hi #{customer.first_name}, you're booked with #{Company.name}: #{job.scheduled_at.strftime('%a %b %-d')}, " \
        "#{job.scheduled_at.strftime('%-l%P')}–#{job.scheduled_end.strftime('%-l%P')}. #{tech} will text you when on the way."
    when :review_request
      "Thanks for choosing #{Company.name}, #{customer.first_name}! If #{tech} did a great job, a quick review helps us a lot: #{Company.review_url}"
    when :invoice
      "#{Company.name}: invoice #{invoice.number} for #{money.(invoice.total_cents)} is ready. View and pay: #{pay_url(invoice)}"
    when :receipt
      "#{Company.name}: we received #{money.(payment.amount_cents)} for invoice #{invoice.number}. Thank you!"
    else
      raise ArgumentError, "Unknown message kind: #{kind}"
    end
  end

  def pay_url(invoice)
    Rails.application.routes.url_helpers.pay_url(invoice.payment_token, **Rails.application.config.action_mailer.default_url_options.to_h)
  end

  def provider
    SmsProviders.current
  end
end
