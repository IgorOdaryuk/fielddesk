# Public "Book a repair" page for one company: /book/:slug.
class BookingsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_account
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to book_path(params[:slug]), alert: "Too many bookings from here. Please call us instead." }

  layout "pay"

  def new
    @booking = Booking.new(slot: params[:slot])
    @days = BookingSlots.new.by_day
  end

  def create
    @booking = Booking.new(params.expect(booking: [ :name, :phone, :email, :street, :unit, :city, :state, :zip,
                                                    :appliance, :brand, :problem, :slot, :website ]))
    # Bots that fill the hidden field get the same success page and no job.
    return redirect_to(book_confirmed_path(@account.slug)) if @booking.spam?

    if @booking.save
      session[:booked_job_id] = @booking.job.id
      redirect_to book_confirmed_path(@account.slug)
    else
      @days = BookingSlots.new.by_day
      render :new, status: :unprocessable_content
    end
  end

  def confirmed
    @job = Job.find_by(id: session[:booked_job_id])
  end

  private
    def set_account
      @account = Account.find_by!(slug: params[:slug], booking_enabled: true)
      set_current_tenant(@account)
    end

    def skip_authorization_check?
      true
    end
end
