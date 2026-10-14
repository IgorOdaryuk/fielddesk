class Customer < ApplicationRecord
  include Auditable

  acts_as_tenant :account

  SOURCES = %w[google_ads lsa organic website yelp thumbtack referral repeat other].freeze

  encrypts :phone, deterministic: true
  encrypts :email, deterministic: true, downcase: true

  has_many :properties, dependent: :destroy
  has_many :jobs, dependent: :restrict_with_error
  has_many :outbound_messages, dependent: :nullify

  accepts_nested_attributes_for :properties, reject_if: :all_blank

  normalizes :phone, with: ->(p) { PhoneNumber.normalize(p) }

  validates :name, presence: true
  validates :source, inclusion: { in: SOURCES }, allow_blank: true
  validate :phone_or_email_present

  scope :alphabetical, -> { order(:name) }

  # Phone and email are encrypted, so only exact matches can hit the database.
  def self.search(query)
    return all if query.blank?

    q = query.strip
    by_contact = where(phone: PhoneNumber.normalize(q)).or(where(email: q.downcase))
    where("customers.name ILIKE ?", "%#{sanitize_sql_like(q)}%").or(by_contact)
  end

  def first_name
    name.split.first
  end

  private
    def phone_or_email_present
      errors.add(:base, "Add a phone number or an email") if phone.blank? && email.blank?
    end
end
