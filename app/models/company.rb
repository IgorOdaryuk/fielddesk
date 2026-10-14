# Read-only settings for the business, from config/company.yml.
module Company
  module_function

  def settings = Rails.application.config_for(:company)
  def name = settings[:name]
  def phone = settings[:phone]
  def email = settings[:email]
  def address = settings[:address]
  def tax_rate_bps = settings[:tax_rate_bps].to_i
  def payment_terms_days = settings[:payment_terms_days].to_i
  def review_url = settings[:review_url]
  def review_request_delay = settings[:review_request_delay_hours].to_i.hours
end
