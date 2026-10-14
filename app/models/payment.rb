class Payment < ApplicationRecord
  include Auditable

  acts_as_tenant :account

  belongs_to :invoice
  belongs_to :recorded_by, class_name: "User", optional: true

  enum :method, { cash: 0, check: 1, card_on_site: 2, online: 3 }, prefix: :paid_by, validate: true

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validate :not_more_than_balance, on: :create

  private
    def not_more_than_balance
      return if invoice.nil? || amount_cents.nil?

      errors.add(:amount_cents, "is more than the balance due") if amount_cents > invoice.balance_cents
    end
end
