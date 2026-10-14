class AuditLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  scope :recent, -> { order(created_at: :desc) }

  def readonly?
    persisted?
  end

  def self.record(action:, auditable: nil, changes: {}, user: Current.user)
    create!(
      action: action,
      auditable: auditable,
      audited_changes: changes,
      user: user,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent&.truncate(255)
    )
  end
end
