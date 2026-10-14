class AuditLogsController < ApplicationController
  def index
    authorize AuditLog
    scope = policy_scope(AuditLog).includes(:user, :auditable).recent
    scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
    scope = scope.where("action LIKE ?", "#{AuditLog.sanitize_sql_like(params[:action_prefix])}%") if params[:action_prefix].present?
    @pagy, @logs = pagy(:offset, scope, limit: 50)
    @users = User.order(:name)
  end
end
