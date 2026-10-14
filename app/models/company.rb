# Settings of the current account, with config/company.yml as the fallback
# for code that runs outside a request (seeds, console).
module Company
  module_function

  def account = ActsAsTenant.current_tenant
  def defaults = @defaults ||= Account.defaults.merge(name: Rails.application.config_for(:company)[:name])

  def name = account&.name || defaults[:name]
  def phone = account&.phone || defaults[:phone]
  def email = account&.email || defaults[:email]
  def address = account&.address || defaults[:address]
  def tax_rate_bps = account&.tax_rate_bps || defaults[:tax_rate_bps]
  def payment_terms_days = account&.payment_terms_days || defaults[:payment_terms_days]
  def review_url = account&.review_url.presence || defaults[:review_url]
  def review_request_delay = Rails.application.config_for(:company)[:review_request_delay_hours].to_i.hours
end
