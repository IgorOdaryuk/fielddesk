# A company using FieldDesk. Every record belongs to exactly one account and
# is invisible to the others (acts_as_tenant scopes every query).
class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :jobs, dependent: :destroy

  normalizes :phone, with: ->(p) { PhoneNumber.normalize(p) }
  normalizes :slug, with: ->(s) { s.to_s.parameterize }

  validates :name, presence: true, length: { maximum: 80 }
  validates :slug, presence: true, uniqueness: true, length: { in: 3..60 }, format: { with: /\A[a-z0-9-]+\z/ },
                   exclusion: { in: %w[admin api app book pay signup login www demo fielddesk] }
  validates :tax_rate_bps, numericality: { only_integer: true, in: 0..2_000 }
  validates :payment_terms_days, numericality: { only_integer: true, in: 0..90 }
  validate :review_url_is_web_link

  before_validation :assign_slug, on: :create

  def self.defaults
    settings = Rails.application.config_for(:company)
    { phone: settings[:phone], email: settings[:email], address: settings[:address], tax_rate_bps: settings[:tax_rate_bps].to_i,
      payment_terms_days: settings[:payment_terms_days].to_i, review_url: settings[:review_url] }
  end

  def tax_rate_percent
    tax_rate_bps / 100.0
  end

  def tax_rate_percent=(value)
    self.tax_rate_bps = (BigDecimal(value.to_s.presence || "0") * 100).round
  rescue ArgumentError
    self.tax_rate_bps = nil
  end

  def to_param = slug

  private
    def review_url_is_web_link
      return if review_url.blank?

      uri = URI.parse(review_url)
      errors.add(:review_url, "must be a full http(s) link") unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(:review_url, "must be a full http(s) link")
    end

    def assign_slug
      return if slug.present? || name.blank?

      base = name.parameterize.first(50).presence || "company"
      candidate = base
      candidate = "#{base}-#{SecureRandom.alphanumeric(4).downcase}" while Account.exists?(slug: candidate)
      self.slug = candidate
    end
end
