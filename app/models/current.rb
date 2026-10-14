class Current < ActiveSupport::CurrentAttributes
  attribute :session, :ip_address, :user_agent, :skip_audit
  delegate :user, to: :session, allow_nil: true
end
