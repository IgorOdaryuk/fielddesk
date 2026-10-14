class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  layout "auth"

  def new
  end

  def create
    user = User.active.authenticate_by(params.permit(:email_address, :password))

    if user
      start_new_session_for user
      AuditLog.record(action: "session.sign_in", auditable: user)
      redirect_to after_authentication_url
    else
      AuditLog.record(action: "session.failed", user: nil,
                      changes: { "email_address" => [ nil, params[:email_address].to_s.strip.downcase.truncate(100) ] })
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    AuditLog.record(action: "session.sign_out", auditable: current_user)
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private
    def skip_authorization_check?
      true
    end
end
