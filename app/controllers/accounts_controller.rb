# Company settings, for admins.
class AccountsController < ApplicationController
  before_action :keep_shared_demo_intact, only: :update
  before_action :set_account

  def edit
  end

  def update
    if @account.update(params.expect(account: [ :name, :phone, :email, :address, :tax_rate_percent, :payment_terms_days, :review_url, :booking_enabled ]))
      redirect_to edit_account_path, notice: "Company settings saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_account
      @account = authorize current_account
    end
end
