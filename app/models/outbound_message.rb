# Every SMS the app sends, real or simulated. In demo mode nothing leaves the
# app: the message is stored as "simulated" and shown in the Outbox.
class OutboundMessage < ApplicationRecord
  belongs_to :customer, optional: true
  belongs_to :job, optional: true

  encrypts :to

  enum :status, { scheduled: 0, sent: 1, simulated: 2, failed: 3, skipped: 4 }, validate: true

  validates :kind, :to, :body, :send_at, presence: true

  scope :newest_first, -> { order(send_at: :desc, id: :desc) }
end
