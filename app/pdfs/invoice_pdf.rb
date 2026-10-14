require "prawn"
require "prawn/table"

# Built-in PDF fonts cover Windows-1252, which is every character we print.
Prawn::Fonts::AFM.hide_m17n_warning = true

# Renders an invoice as a one-page US Letter PDF.
class InvoicePdf
  include ActiveSupport::NumberHelper

  INK = "0F172A".freeze
  MUTED = "64748B".freeze
  LINE = "E2E8F0".freeze

  def initialize(invoice)
    @invoice = invoice
    @job = invoice.job
    @customer = @job.customer
  end

  def render
    Prawn::Document.new(page_size: "LETTER", margin: 48, info: { Title: "Invoice #{@invoice.number}", Creator: "FieldDesk" }) do |pdf|
      pdf.font_size 10
      pdf.fill_color INK
      header(pdf)
      parties(pdf)
      items(pdf)
      totals(pdf)
      footer(pdf)
    end.render
  end

  private
    def money(cents) = number_to_currency(cents / 100.0)

    def header(pdf)
      pdf.text Company.name, size: 18, style: :bold
      pdf.fill_color MUTED
      pdf.text [ Company.address, PhoneNumber.format(Company.phone), Company.email ].join("  ·  ")
      pdf.fill_color INK
      pdf.bounding_box([ pdf.bounds.right - 200, pdf.bounds.top ], width: 200) do
        pdf.text "INVOICE", size: 18, style: :bold, align: :right
        pdf.text @invoice.number, align: :right
        pdf.text "Status: #{@invoice.status.upcase}", align: :right, color: @invoice.paid? ? "059669" : MUTED
      end
      pdf.move_down 28
    end

    def parties(pdf)
      top = pdf.cursor
      pdf.bounding_box([ 0, top ], width: 260) do
        label(pdf, "BILL TO")
        pdf.text @customer.name, style: :bold
        pdf.text @job.property.one_line
        pdf.text PhoneNumber.format(@customer.phone) if @customer.phone.present?
      end
      pdf.bounding_box([ 300, top ], width: pdf.bounds.width - 300) do
        label(pdf, "DETAILS")
        [ [ "Issued", (@invoice.sent_at || @invoice.created_at).to_date.strftime("%b %-d, %Y") ],
          [ "Due", @invoice.due_on&.strftime("%b %-d, %Y") || "On receipt" ],
          [ "Job", "#{@job.number} · #{[ @job.brand, @job.appliance ].compact_blank.join(' ')}" ],
          [ "Technician", @job.technician&.name || "—" ] ].each do |k, v|
          pdf.text "#{k}: #{v}"
        end
      end
      pdf.move_down 24
    end

    def items(pdf)
      rows = [ [ "Description", "Type", "Qty", "Unit price", "Amount" ] ]
      @invoice.items.each do |item|
        rows << [ item.description + (item.taxable? ? " *" : ""), item.kind.humanize, item.quantity.to_s("F").sub(/\.0\z/, ""),
                  money(item.unit_price_cents), money(item.line_total_cents) ]
      end
      pdf.table(rows, header: true, width: pdf.bounds.width, column_widths: { 1 => 60, 2 => 40, 3 => 80, 4 => 80 },
                      cell_style: { borders: [ :bottom ], border_color: LINE, padding: [ 7, 6 ] }) do |t|
        t.row(0).font_style = :bold
        t.row(0).text_color = MUTED
        t.columns(2..4).align = :right
      end
    end

    def totals(pdf)
      pdf.move_down 12
      lines = [ [ "Subtotal", money(@invoice.subtotal_cents) ],
                [ "Sales tax (#{(@invoice.tax_rate_bps / 100.0).to_s.sub(/\.0\z/, '')}% on parts *)", money(@invoice.tax_cents) ],
                [ "Total", money(@invoice.total_cents) ] ]
      lines << [ "Paid", "-#{money(@invoice.paid_cents)}" ] if @invoice.paid_cents.positive?
      lines << [ "Balance due", money(@invoice.balance_cents) ]
      pdf.table(lines, position: :right, width: 260, cell_style: { borders: [], padding: [ 3, 6 ] }) do |t|
        t.columns(1).align = :right
        t.row(-1).font_style = :bold
        t.row(-1).size = 12
      end
    end

    def footer(pdf)
      pdf.move_down 24
      if @invoice.payments.any?
        label(pdf, "PAYMENTS")
        @invoice.payments.each do |p|
          pdf.text "#{p.received_at.strftime('%b %-d, %Y')}  ·  #{p.method.humanize}  ·  #{money(p.amount_cents)}"
        end
        pdf.move_down 12
      end
      pdf.text @invoice.notes, color: MUTED if @invoice.notes.present?
      pdf.fill_color MUTED
      pdf.text "Pay online: #{Messaging.pay_url(@invoice)}" if @invoice.payable?
      pdf.text "DEMO DOCUMENT · fictional company and customer", size: 8 if Demo.enabled?
      pdf.fill_color INK
    end

    def label(pdf, text)
      pdf.text text, size: 8, style: :bold, color: MUTED
      pdf.move_down 4
    end
end
