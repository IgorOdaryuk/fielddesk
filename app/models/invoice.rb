class Invoice < ApplicationRecord
  include Auditable

  belongs_to :job
  has_one :customer, through: :job
  has_many :items, -> { order(:created_at) }, class_name: "InvoiceItem", dependent: :destroy, inverse_of: :invoice
  has_many :payments, -> { order(:received_at) }, dependent: :restrict_with_error

  has_secure_token :payment_token, on: :initialize

  enum :status, { draft: 0, sent: 1, paid: 2, void: 3 }, validate: true

  validates :tax_rate_bps, numericality: { only_integer: true, in: 0..2_000 }

  scope :newest_first, -> { order(created_at: :desc) }
  scope :outstanding, -> { sent.where("paid_cents < total_cents") }

  def self.open_for!(job)
    job.invoice || job.create_invoice!(tax_rate_bps: Company.tax_rate_bps, due_on: Date.current + Company.payment_terms_days)
  end

  def balance_cents
    [ total_cents - paid_cents, 0 ].max
  end

  def editable?
    (draft? || sent?) && payments.none?
  end

  def payable?
    sent? && balance_cents.positive?
  end

  def overdue?
    payable? && due_on.present? && due_on < Date.current
  end

  def recalculate!
    subtotal = items.sum(&:line_total_cents)
    taxable = items.select(&:taxable?).sum(&:line_total_cents)
    tax = (taxable * tax_rate_bps / 10_000.0).round
    update!(subtotal_cents: subtotal, tax_cents: tax, total_cents: subtotal + tax)
  end

  def send_to_customer!
    raise ArgumentError, "Add at least one line before sending" if total_cents.zero?
    raise ArgumentError, "This invoice can't be sent" unless draft? || sent?

    update!(status: :sent, sent_at: Time.current)
    Messaging.notify(:invoice, job: job, invoice: self)
  end

  # Idempotent for gateway payments: the same gateway_id is recorded once.
  def record_payment!(amount_cents:, method:, by: nil, reference: nil, gateway: nil, gateway_id: nil)
    return payments.find_by(gateway: gateway, gateway_id: gateway_id) if gateway_id && payments.exists?(gateway: gateway, gateway_id: gateway_id)
    raise ArgumentError, "Nothing is owed on this invoice" unless (draft? || sent?) && balance_cents.positive?

    payment = transaction do
      self.status = :sent if draft?
      self.sent_at ||= Time.current
      created = payments.create!(amount_cents: amount_cents, method: method, recorded_by: by, reference: reference,
                                 gateway: gateway, gateway_id: gateway_id, received_at: Time.current)
      self.paid_cents += amount_cents
      if balance_cents.zero?
        self.status = :paid
        self.paid_at = Time.current
      end
      save!
      created
    end
    Messaging.notify(:receipt, job: job, invoice: self, payment: payment)
    payment
  end

  def void!
    raise ArgumentError, "Paid invoices can't be voided" if paid? || payments.any?

    update!(status: :void, voided_at: Time.current)
  end
end
