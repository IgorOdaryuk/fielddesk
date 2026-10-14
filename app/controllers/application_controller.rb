class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_request_context
  after_action :verify_authorized, unless: :skip_authorization_check?

  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  helper_method :current_user

  private
    def current_user
      Current.user
    end
    alias_method :pundit_user, :current_user

    def set_request_context
      Current.ip_address = request.remote_ip
      Current.user_agent = request.user_agent
    end

    def skip_authorization_check?
      false
    end

    def forbidden
      AuditLog.record(action: "access.denied", changes: { "path" => [ nil, request.path ] }) if current_user
      respond_to do |format|
        format.html { redirect_back_or_to root_path, alert: "You don't have access to that." }
        format.any { head :forbidden }
      end
    end
end
