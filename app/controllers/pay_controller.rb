# The customer-facing payment page. Reached by the unguessable token in the
# invoice text message; no account needed. Shows the minimum: first name,
# city, line items and totals.
class PayController < ApplicationController
  allow_unauthenticated_access
  before_action :set_invoice
  before_action :require_simulated_gateway, only: %i[ checkout charge ]
  rate_limit to: 10, within: 5.minutes, only: %i[ start charge ], with: -> { redirect_to pay_path(params[:token]), alert: "Too many attempts. Try again in a few minutes." }

  layout "pay"

  def show
    respond_to do |format|
      format.html
      format.pdf do
        send_data InvoicePdf.new(@invoice).render, filename: "#{@invoice.number}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end

  def start
    return redirect_to(pay_path(@invoice.payment_token), alert: "This invoice has nothing left to pay.") unless @invoice.payable?

    url = gateway.checkout_url(@invoice, success_url: pay_url(@invoice.payment_token, paid: 1), cancel_url: pay_url(@invoice.payment_token))
    redirect_to url, allow_other_host: !gateway.simulated?
  end

  def checkout
  end

  def charge
    return redirect_to(pay_path(@invoice.payment_token)) unless @invoice.payable?

    result = gateway.charge(params[:card_number])
    if result[:ok]
      @invoice.record_payment!(amount_cents: @invoice.balance_cents, method: :online, gateway: gateway.name, gateway_id: result[:id])
      redirect_to pay_path(@invoice.payment_token), notice: "Payment received. Thank you!"
    else
      redirect_to pay_checkout_path(@invoice.payment_token), alert: result[:error]
    end
  end

  private
    def set_invoice
      # The token is the only key the customer has, so look it up across
      # accounts, then work inside the invoice's company.
      @invoice = ActsAsTenant.without_tenant { Invoice.where.not(status: :draft).find_by!(payment_token: params[:token].to_s) }
      set_current_tenant(@invoice.account)
    end

    def gateway
      @gateway ||= PaymentGateways.current
    end

    def require_simulated_gateway
      head :not_found unless gateway.simulated?
    end

    def skip_authorization_check?
      true
    end
end
