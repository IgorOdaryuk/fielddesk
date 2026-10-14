class InvoiceItemsController < ApplicationController
  before_action :set_invoice

  def create
    item = @invoice.items.build(params.expect(invoice_item: [ :kind, :description, :quantity, :unit_price ]))
    if item.save
      redirect_back_or_to @invoice, notice: "Line added."
    else
      redirect_back_or_to @invoice, alert: item.errors.full_messages.to_sentence
    end
  end

  def destroy
    item = @invoice.items.find(params[:id])
    item.destroy!
    redirect_back_or_to @invoice, notice: "Line removed.", status: :see_other
  end

  private
    def set_invoice
      @invoice = authorize Invoice.find(params[:invoice_id]), :update?
    end
end
