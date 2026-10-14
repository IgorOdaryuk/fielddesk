class InvoiceItem < ApplicationRecord
  include Auditable

  belongs_to :invoice, inverse_of: :items

  enum :kind, { labor: 0, part: 1, fee: 2 }, validate: true

  validates :description, presence: true, length: { maximum: 200 }
  validates :quantity, numericality: { greater_than: 0, less_than: 1_000 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 10_000_000 }
  validate :invoice_is_editable

  # One after_commit, not after_save_commit + after_destroy_commit: Rails keeps
  # only the last of those when both name the same method.
  after_commit :recalculate_invoice

  # Parts are taxed, labor and fees aren't (the common US sales tax rule).
  before_validation { self.taxable = part? }

  def unit_price=(dollars)
    self.unit_price_cents = (BigDecimal(dollars.to_s.delete("$,").presence || "0") * 100).round
  rescue ArgumentError
    self.unit_price_cents = nil
  end

  def unit_price
    unit_price_cents && unit_price_cents / 100.0
  end

  def line_total_cents
    (quantity * unit_price_cents).round
  end

  private
    def invoice_is_editable
      errors.add(:base, "This invoice can no longer be changed") unless invoice&.editable?
    end

    def recalculate_invoice
      Invoice.find_by(id: invoice_id)&.recalculate!
    end
end
