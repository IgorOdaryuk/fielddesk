# Writes an AuditLog row for every create, update and destroy, attributed to
# Current.user. Encrypted and secret columns are logged as "[FILTERED]" so the
# audit trail never becomes a second copy of customer PII.
module Auditable
  extend ActiveSupport::Concern

  IGNORED_COLUMNS = %w[created_at updated_at].freeze

  included do
    after_create_commit  { write_audit("create", audit_changes) }
    after_update_commit  { write_audit("update", audit_changes) if audit_changes.any? }
    after_destroy_commit { write_audit("destroy", {}) }
  end

  private
    def audit_changes
      saved_changes.except(*IGNORED_COLUMNS).to_h do |column, values|
        if self.class.audit_filtered?(column)
          [ column, [ "[FILTERED]", "[FILTERED]" ] ]
        else
          [ column, values ]
        end
      end
    end

    def write_audit(action, changes)
      return if Current.skip_audit

      AuditLog.record(action: "#{model_name.singular}.#{action}", auditable: self, changes: changes)
    end

  class_methods do
    def audit_filtered?(column)
      encrypted_attributes.to_a.include?(column.to_sym) || column.include?("password")
    end
  end
end
