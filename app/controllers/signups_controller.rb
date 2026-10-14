# Self-serve sign-up: a new company with its first admin, optionally filled
# with sample data so there is something to click through right away.
class SignupsController < ApplicationController
  allow_unauthenticated_access
  before_action :require_signups_open
  rate_limit to: 5, within: 1.hour, only: :create, with: -> { redirect_to new_signup_path, alert: "Too many sign-ups from here. Try again later." }

  layout "auth"

  def new
    @signup = Signup.new(sample_data: true)
  end

  def create
    @signup = Signup.new(params.expect(signup: [ :company_name, :name, :email_address, :password, :sample_data ]))

    if (user = @signup.save)
      start_new_session_for user
      AuditLog.record(action: "account.created", auditable: user.account, user: user, account: user.account)
      redirect_to dashboard_path, notice: "Welcome to FieldDesk!"
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def require_signups_open
      redirect_to new_session_path, alert: "Sign-ups are closed." unless Signup.open?
    end

    def skip_authorization_check?
      true
    end
end
