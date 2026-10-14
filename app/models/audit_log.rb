class AuditLog < ApplicationRecord
  # Optional: a failed sign-in for an unknown email belongs to no company.
  acts_as_tenant :account, optional: true

  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  scope :recent, -> { order(created_at: :desc) }

  def readonly?
    persisted?
  end

  def self.record(action:, auditable: nil, changes: {}, user: Current.user, account: ActsAsTenant.current_tenant || user&.account)
    attrs = { account: account, action: action, auditable: auditable, audited_changes: changes, user: user,
              ip_address: Current.ip_address, user_agent: Current.user_agent&.truncate(255) }
    # A failed sign-in for an unknown email has no company to file it under.
    account ? ActsAsTenant.with_tenant(account) { create!(attrs) } : ActsAsTenant.without_tenant { create!(attrs) }
  end
end
