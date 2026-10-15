class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  set_current_tenant_through_filter
  before_action :set_request_context
  before_action :set_account_from_user
  after_action :verify_authorized, unless: :skip_authorization_check?

  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  helper_method :current_user, :current_account

  private
    def current_user
      Current.user
    end
    alias_method :pundit_user, :current_user

    def current_account
      ActsAsTenant.current_tenant
    end

    def set_account_from_user
      set_current_tenant(current_user.account) if current_user
    end

    def set_request_context
      Current.ip_address = request.remote_ip
      Current.user_agent = request.user_agent
    end

    def skip_authorization_check?
      false
    end

    def keep_shared_demo_intact
      return unless current_account&.shared_demo?

      redirect_back_or_to root_path, alert: "The shared demo keeps its team and settings as they are, so everyone can sign in. " \
                                            "Create your own sandbox company to try this."
    end

    def forbidden
      AuditLog.record(action: "access.denied", changes: { "path" => [ nil, request.path ] }) if current_user
      respond_to do |format|
        format.html { redirect_back_or_to root_path, alert: "You don't have access to that." }
        format.any { head :forbidden }
      end
    end
end
