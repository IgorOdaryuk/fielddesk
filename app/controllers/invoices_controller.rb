class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[ show update send_invoice void ]

  def index
    authorize Invoice
    scope = policy_scope(Invoice).includes(job: :customer).newest_first
    scope = scope.where(status: params[:status]) if Invoice.statuses.key?(params[:status])
    scope = scope.outstanding if params[:status] == "outstanding"
    @pagy, @invoices = pagy(:offset, scope, limit: 25)
    @outstanding_cents = Invoice.outstanding.sum("total_cents - paid_cents")
    @paid_this_month_cents = Payment.where(received_at: Time.current.beginning_of_month..).sum(:amount_cents)
  end

  def show
    respond_to do |format|
      format.html { @item = InvoiceItem.new(kind: :labor, quantity: 1) }
      format.pdf do
        send_data InvoicePdf.new(@invoice).render, filename: "#{@invoice.number}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end

  def create
    job = Job.find(params[:job_id])
    authorize Invoice.new(job_id: job.id) # job_id, not job: avoids setting job.invoice via inverse_of

    invoice = Invoice.open_for!(job)
    redirect_to invoice_path_for(invoice)
  end

  def update
    if @invoice.update(params.expect(invoice: [ :notes, :due_on ]))
      redirect_to invoice_path_for(@invoice), notice: "Invoice updated."
    else
      redirect_to invoice_path_for(@invoice), alert: @invoice.errors.full_messages.to_sentence
    end
  end

  def send_invoice
    @invoice.send_to_customer!
    redirect_to invoice_path_for(@invoice), notice: "Invoice sent to #{@invoice.customer.name} by text."
  rescue ArgumentError => e
    redirect_to invoice_path_for(@invoice), alert: e.message
  end

  def void
    @invoice.void!
    redirect_to invoice_path_for(@invoice), notice: "Invoice voided."
  rescue ArgumentError => e
    redirect_to invoice_path_for(@invoice), alert: e.message
  end

  private
    def set_invoice
      @invoice = authorize Invoice.find(params[:id])
    end

    # Technicians stay inside their cabinet.
    def invoice_path_for(invoice)
      current_user.staff? ? invoice_path(invoice) : my_job_path(invoice.job, anchor: "invoice")
    end
    helper_method :invoice_path_for
end
