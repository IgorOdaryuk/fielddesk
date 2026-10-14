# Fills an account with a believable working history: a team, customers,
# jobs around today, invoices, payments, texts and an audit trail.
# Used by db/seeds.rb and by sandbox sign-ups. Every person, address and phone
# number is generated; phones sit in the 555-0100..0199 range reserved for fiction.
class DemoData
  PASSWORD = "demo-password".freeze

  TEAM = [
    [ "Dana Brooks", "dispatch", :dispatcher, "#64748b" ],
    [ "Mike Torres", "mike", :technician, "#2563eb" ],
    [ "Sarah Kim", "sarah", :technician, "#db2777" ],
    [ "James Carter", "james", :technician, "#059669" ],
    [ "Luis Ortega", "luis", :technician, "#d97706" ]
  ].freeze

  CITIES = [ [ "Tampa", "336" ], [ "St. Petersburg", "337" ], [ "Clearwater", "337" ], [ "Brandon", "335" ],
             [ "Wesley Chapel", "335" ], [ "Largo", "337" ], [ "Riverview", "335" ], [ "Lutz", "335" ] ].freeze
  SOURCES = %w[google_ads google_ads google_ads lsa lsa organic organic yelp thumbtack referral repeat].freeze
  BRANDS = %w[Whirlpool Samsung LG GE Frigidaire Maytag KitchenAid Bosch Kenmore].freeze

  PROBLEMS = {
    "Refrigerator" => [ "Not cooling, freezer fine", "Leaking water under the crisper", "Loud buzzing from the back", "Ice buildup in the freezer" ],
    "Washer" => [ "Won't drain, water stays in drum", "Shakes violently on spin", "Error code F21", "Door won't unlock" ],
    "Dryer" => [ "Runs but no heat", "Squealing noise", "Takes three cycles to dry", "Won't start" ],
    "Dishwasher" => [ "Not draining", "Dishes come out dirty", "Leaking at the door", "Won't start, lights blink" ],
    "Oven" => [ "Won't heat past 200°F", "Bake element sparked", "Door won't close fully" ],
    "Range" => [ "Burner won't ignite", "Clicking non-stop" ],
    "Microwave" => [ "Runs but doesn't heat", "Turntable stopped" ],
    "Ice maker" => [ "Not making ice", "Ice tastes bad, slow fill" ]
  }.freeze

  PARTS = {
    "Refrigerator" => [ [ "Defrost thermostat", 4_800 ], [ "Evaporator fan motor", 8_900 ], [ "Start relay", 3_900 ] ],
    "Washer" => [ [ "Drain pump", 7_900 ], [ "Door lock assembly", 9_400 ], [ "Shock absorbers (pair)", 6_200 ] ],
    "Dryer" => [ [ "Heating element", 8_400 ], [ "Thermal fuse", 2_900 ], [ "Drum belt", 3_400 ] ],
    "Dishwasher" => [ [ "Drain pump", 8_200 ], [ "Door gasket", 4_600 ], [ "Control board", 18_900 ] ],
    "Oven" => [ [ "Bake element", 6_900 ], [ "Temperature sensor", 5_400 ] ],
    "Range" => [ [ "Igniter", 5_900 ], [ "Spark module", 8_800 ] ],
    "Microwave" => [ [ "Magnetron", 12_900 ], [ "Turntable motor", 3_600 ] ],
    "Ice maker" => [ [ "Ice maker assembly", 14_900 ], [ "Water inlet valve", 6_400 ] ]
  }.freeze

  TECH_NOTES = [
    "Diagnosed a failed drain pump, replaced on site.", "Needs a new control board, part ordered, ETA 3 days.",
    "Cleaned condenser coils, cooling back to normal.", "Replaced door gasket. Tested, no leaks.",
    "Customer approved the estimate.", "Thermal fuse blown. Replaced and cleaned the vent line.",
    "Customer wasn't home, left a door tag.", "Igniter replaced, all burners light."
  ].freeze

  # login_suffix keeps demo emails globally unique across sandbox accounts:
  # mike@fielddesk.demo for the main demo, mike.<suffix>@fielddesk.demo for others.
  def self.populate(account, customers: 140, admin: nil, login_suffix: nil, seed: nil)
    new(account, customers:, admin:, login_suffix:, seed:).populate
  end

  def initialize(account, customers:, admin:, login_suffix:, seed:)
    @account, @customer_count, @admin, @login_suffix = account, customers, admin, login_suffix
    @rng = seed ? Random.new(seed) : Random.new
    @today = Time.zone.today
  end

  def populate
    previous_faker_random, Faker::Config.random = Faker::Config.random, @rng
    previous_skip, Current.skip_audit = Current.skip_audit, true

    ActsAsTenant.with_tenant(@account) do
      Job.suppressing_turbo_broadcasts do
        create_team
        create_customers
        create_jobs
        create_invoices
        create_texts
        create_audit_trail
      end
    end
    self
  ensure
    Faker::Config.random = previous_faker_random
    Current.skip_audit = previous_skip
  end

  def self.email_for(login, suffix) = suffix ? "#{login}.#{suffix}@fielddesk.demo" : "#{login}@fielddesk.demo"

  private
    def rand(arg = nil) = arg ? @rng.rand(arg) : @rng.rand
    def pick(list) = list.sample(random: @rng)

    def create_team
      @admin ||= User.create!(name: "Alex Rivera", email_address: self.class.email_for("admin", @login_suffix),
                              password: PASSWORD, role: :admin, color: "#0f172a")
      users = TEAM.map do |name, login, role, color|
        User.create!(name: name, email_address: self.class.email_for(login, @login_suffix), password: PASSWORD, role: role, color: color)
      end
      @dispatcher = users.find(&:dispatcher?)
      @techs = users.select(&:technician?)
    end

    def create_customers
      @customers = Array.new(@customer_count) do |i|
        city, zip3 = pick(CITIES)
        Customer.create!(
          name: "#{Faker::Name.first_name} #{Faker::Name.last_name}",
          phone: "(#{pick(%w[813 727])}) 555-#{format('%04d', 100 + i % 100)}",
          email: (Faker::Internet.email(domain: "example.com") if rand < 0.7),
          source: pick(SOURCES),
          notes: (pick([ "Prefers text over calls", "Has a dog, ring the bell twice", "Elderly, speak to daughter first", "Warranty customer" ]) if rand < 0.2),
          properties_attributes: [ {
            street: Faker::Address.street_address, city: city, state: "FL", zip: "#{zip3}#{format('%02d', rand(1..99))}",
            access_notes: (pick([ "Gate code #4512", "Park in the driveway", "Side door, garage fridge", "Condo, call from lobby" ]) if rand < 0.3)
          } ]
        )
      end
    end

    def create_jobs
      booked = Hash.new { |h, k| h[k] = [] } # [tech_id, date] => start hours, so nobody is double-booked
      @customers.each do |customer|
        rand(1..4).times do
          # Weighted toward this week so the board looks like a working day.
          day = rand < 0.35 ? @today + rand(-1..3) : @today + rand(-60..7)
          appliance = pick(PROBLEMS.keys)
          tech, hour = @techs.shuffle(random: @rng).product([ 8, 10, 12, 14, 16 ].shuffle(random: @rng)).find { |t, h| booked[[ t.id, day ]].exclude?(h) }
          next unless tech

          booked[[ tech.id, day ]] << hour
          slot = Time.zone.local(day.year, day.month, day.day, hour)
          status = status_for(day, slot)

          attrs = {
            customer: customer, property: customer.properties.first, appliance: appliance, brand: pick(BRANDS),
            model_number: ("#{('A'..'Z').to_a.sample(3, random: @rng).join}#{rand(1000..9999)}" if rand < 0.6),
            problem: pick(PROBLEMS[appliance]), source: customer.source, created_by: pick([ @admin, @dispatcher ]),
            priority: rand < 0.1 ? :urgent : :normal, duration_minutes: pick([ 60, 90, 120, 120 ]),
            status: status, created_at: [ slot - rand(1..5).days, Time.current - rand(1..72).hours ].min
          }
          attrs.merge!(technician: tech, scheduled_at: slot) unless status == :unscheduled
          attrs[:cancel_reason] = pick([ "Customer fixed it", "Went with another company", "Rescheduled, will call back" ]) if status == :canceled
          attrs[:started_at] = slot + 10.minutes if status.in?(%i[in_progress completed])
          attrs[:completed_at] = slot + attrs[:duration_minutes].minutes if status == :completed

          job = Job.create!(attrs)
          job.notes.create!(user: tech, body: pick(TECH_NOTES), created_at: attrs[:started_at] + 30.minutes) if status.in?(%i[completed in_progress])
        end
      end
    end

    # Today follows the clock: earlier slots are done, the current one is being worked.
    def status_for(day, slot)
      if day < @today then rand < 0.88 ? :completed : :canceled
      elsif day == @today
        minutes_in = (Time.current - slot) / 60
        if minutes_in > 120 then rand < 0.85 ? :completed : :in_progress
        elsif minutes_in.positive? then :in_progress
        elsif minutes_in > -45 then :en_route
        else :scheduled
        end
      else rand < 0.85 ? :scheduled : :unscheduled
      end
    end

    # Most paid (cash, check, card on site, online), some waiting, a few overdue.
    def create_invoices
      Job.completed.includes(:customer, :technician).find_each do |job|
        next if rand < 0.08

        done = job.completed_at
        invoice = job.create_invoice!(tax_rate_bps: Company.tax_rate_bps, due_on: done.to_date + Company.payment_terms_days,
                                      created_at: done, notes: "90-day warranty on parts and labor.")
        invoice.items.create!(kind: :fee, description: "Diagnostic visit", quantity: 1, unit_price_cents: 8_900)
        if rand < 0.8
          name, price = pick(PARTS.fetch(job.appliance, [ [ "Replacement part", 6_500 ] ]))
          invoice.items.create!(kind: :part, description: name, quantity: 1, unit_price_cents: price)
          invoice.items.create!(kind: :labor, description: "Repair labor", quantity: pick([ 1, 1, 1.5, 2 ]), unit_price_cents: 9_500)
        end
        invoice.reload.recalculate!
        invoice.update_columns(status: Invoice.statuses[:sent], sent_at: done + 10.minutes)

        unpaid = done > 3.days.ago ? rand < 0.4 : rand < 0.07
        next if unpaid

        method = pick(%i[card_on_site card_on_site cash check online])
        paid_at = [ method == :online ? done + rand(2..48).hours : done + 15.minutes, 5.minutes.ago ].min
        invoice.payments.create!(amount_cents: invoice.total_cents, method: method, received_at: paid_at,
                                 recorded_by: (job.technician unless method == :online),
                                 reference: (rand(1000..9999).to_s if method == :check),
                                 gateway: ("simulated" if method == :online), gateway_id: ("sim_ch_#{SecureRandom.hex(8)}" if method == :online))
        invoice.update_columns(status: Invoice.statuses[:paid], paid_cents: invoice.total_cents, paid_at: paid_at)
      end
    end

    # The texts those events would have produced, so the outbox has history.
    def create_texts
      Job.where(scheduled_at: 7.days.ago.beginning_of_day..).where.not(technician_id: nil)
         .where(status: %i[en_route in_progress completed]).includes(:customer, :technician, :invoice).find_each do |job|
        text = ->(kind, at, status: :simulated, **ctx) do
          OutboundMessage.create!(kind: kind.to_s, customer: job.customer, job: job, to: job.customer.phone, status: status,
                                  provider: ("simulated" unless status == :scheduled), sent_at: (at unless status == :scheduled),
                                  body: Messaging.body_for(kind, job: job, customer: job.customer, **ctx), send_at: at)
        end
        text.(:on_my_way, job.scheduled_at - 25.minutes)
        next unless job.completed?

        if (invoice = job.invoice)
          text.(:invoice, invoice.sent_at, invoice: invoice)
          payment = invoice.payments.first
          text.(:receipt, payment.received_at, invoice: invoice, payment: payment) if payment
        end
        review_at = job.completed_at + Company.review_request_delay
        text.(:review_request, review_at, status: review_at.past? ? :simulated : :scheduled)
      end
    end

    # Who moved recent jobs and when, plus sign-ins and two failed attempts.
    def create_audit_trail
      Job.where(scheduled_at: (@today - 2).beginning_of_day..@today.end_of_day).where.not(technician_id: nil).find_each do |job|
        steps = { "en_route" => -25, "in_progress" => 10, "completed" => job.duration_minutes }
        reached = %w[en_route in_progress completed].take(%w[scheduled en_route in_progress completed].index(job.status).to_i)
        previous = "scheduled"
        reached.each do |status|
          AuditLog.create!(action: "job.update", auditable: job, user: job.technician, ip_address: "10.0.0.#{job.technician_id % 250}",
                           audited_changes: { "status" => [ previous, status ] }, created_at: job.scheduled_at + steps[status].minutes)
          previous = status
        end
      end
      [ [ @admin, 9 ], [ @dispatcher, 8 ], *@techs.map { [ _1, 7 ] } ].each do |user, hour|
        AuditLog.create!(action: "session.sign_in", auditable: user, user: user, ip_address: "10.0.0.#{user.id % 250}",
                         created_at: @today.in_time_zone.change(hour: hour, min: rand(0..40)))
      end
      2.times do |i|
        AuditLog.create!(action: "session.failed", ip_address: "203.0.113.#{40 + i}", created_at: @today.in_time_zone.change(hour: 3, min: 12 + i),
                         audited_changes: { "email_address" => [ nil, @admin.email_address ] })
      end
    end
end
