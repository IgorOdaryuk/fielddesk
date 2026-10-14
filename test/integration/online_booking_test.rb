require "test_helper"

class OnlineBookingTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:sunshine)
    @slot = BookingSlots.new.by_day.flat_map(&:last).find(&:available?)
  end

  def booking_params(**overrides)
    { name: "Rosa Diaz", phone: "(813) 555-0144", email: "rosa@example.com", street: "12 Elm St", city: "Tampa", state: "FL",
      zip: "33606", appliance: "Dishwasher", brand: "Bosch", problem: "Not draining", slot: @slot.key }.merge(overrides)
  end

  test "customer books a window and gets a confirmation text" do
    get book_path(@account.slug)
    assert_response :success
    assert_select "input[type=radio][value='#{@slot.key}']"

    assert_difference -> { Job.count } => 1, -> { Customer.count } => 1 do
      post book_path(@account.slug), params: { booking: booking_params }
    end
    assert_redirected_to book_confirmed_path(@account.slug)
    follow_redirect!
    assert_select "h1", "You're booked!"

    job = Job.newest_first.first
    assert job.scheduled?
    assert_equal "website", job.source
    assert_equal @slot.starts_at, job.scheduled_at
    assert_nil job.created_by
    assert_equal "booking_confirmation", job.outbound_messages.last.kind
  end

  test "a returning customer is matched by phone" do
    assert_no_difference -> { Customer.count } do
      post book_path(@account.slug), params: { booking: booking_params(phone: "813-555-0101", name: "Jane D.") }
    end
    assert_equal customers(:jane), Job.newest_first.first.customer
  end

  test "a window with every technician busy is refused" do
    techs = User.technicians.to_a
    starts = @slot.starts_at
    techs.each_with_index do |tech, i|
      Job.create!(customer: customers(:bob), property: properties(:bob_home), appliance: "Oven", problem: "x",
                  status: :scheduled, technician: tech, scheduled_at: starts, duration_minutes: 120)
    end

    assert_no_difference -> { Job.count } do
      post book_path(@account.slug), params: { booking: booking_params }
    end
    assert_response :unprocessable_content
    assert_match "was just taken", response.body
  end

  test "bots filling the honeypot create nothing" do
    assert_no_difference -> { Job.count } do
      post book_path(@account.slug), params: { booking: booking_params(website: "http://spam.example") }
    end
  end

  test "each company's page only offers its own technicians" do
    # Bayside has no technicians, so Sunshine's free windows must not show up there.
    get book_path(accounts(:bayside).slug)
    assert_select "input[type=radio]:not([disabled])", count: 0

    assert_no_difference -> { Job.count } do
      post book_path(accounts(:bayside).slug), params: { booking: booking_params }
    end
    assert_response :unprocessable_content
  end

  test "booking can be switched off" do
    @account.update!(booking_enabled: false)
    get book_path(@account.slug)
    assert_response :not_found
  end
end
