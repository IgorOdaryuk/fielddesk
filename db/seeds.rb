# Demo data for a fictional appliance repair company in the Tampa Bay area.
# Every person, address and phone number here is generated: phone numbers sit
# in the 555-0100..0199 range reserved for fiction. Safe to run repeatedly.

if User.exists? && ENV["RESEED"].blank?
  puts "Seeds skipped: data already present (RESEED=1 to rebuild)"
  return
end

Faker::Config.random = Random.new(42)
srand(42)
Current.skip_audit = true
Job.suppressing_turbo_broadcasts do
if ENV["RESEED"].present?
  [ OutboundMessage, Payment, InvoiceItem, Invoice, AuditLog, JobNote, Job, Property, Customer, Session, User ].each(&:delete_all)
  ActiveStorage::Attachment.delete_all
end

password = "demo-password"
admin = User.create!(name: "Alex Rivera", email_address: "admin@fielddesk.demo", password: password, role: :admin, color: "#0f172a")
dispatcher = User.create!(name: "Dana Brooks", email_address: "dispatch@fielddesk.demo", password: password, role: :dispatcher, color: "#64748b")
techs = [
  [ "Mike Torres", "mike", "#2563eb" ], [ "Sarah Kim", "sarah", "#db2777" ],
  [ "James Carter", "james", "#059669" ], [ "Luis Ortega", "luis", "#d97706" ]
].map do |name, login, color|
  User.create!(name: name, email_address: "#{login}@fielddesk.demo", password: password, role: :technician, color: color)
end

cities = [
  [ "Tampa", "336" ], [ "St. Petersburg", "337" ], [ "Clearwater", "337" ], [ "Brandon", "335" ],
  [ "Wesley Chapel", "335" ], [ "Largo", "337" ], [ "Riverview", "335" ], [ "Lutz", "335" ]
]
weighted_sources = %w[google_ads google_ads google_ads lsa lsa organic organic yelp thumbtack referral repeat]
area_codes = %w[813 727]

customers = Array.new(140) do |i|
  city, zip3 = cities.sample
  Customer.create!(
    name: "#{Faker::Name.first_name} #{Faker::Name.last_name}",
    phone: "(#{area_codes.sample}) 555-#{format('%04d', 100 + i % 100)}",
    email: (Faker::Internet.email(domain: "example.com") if rand < 0.7),
    source: weighted_sources.sample,
    notes: ([ "Prefers text over calls", "Has a dog, ring the bell twice", "Elderly, speak to daughter first", "Warranty customer" ].sample if rand < 0.2),
    properties_attributes: [ {
      street: Faker::Address.street_address, city: city, state: "FL", zip: "#{zip3}#{format('%02d', rand(1..99))}",
      access_notes: ([ "Gate code #4512", "Park in the driveway", "Side door, garage fridge", "Condo, call from lobby" ].sample if rand < 0.3)
    } ]
  )
end

problems = {
  "Refrigerator" => [ "Not cooling, freezer fine", "Leaking water under the crisper", "Loud buzzing from the back", "Ice buildup in the freezer" ],
  "Washer" => [ "Won't drain, water stays in drum", "Shakes violently on spin", "Error code F21", "Door won't unlock" ],
  "Dryer" => [ "Runs but no heat", "Squealing noise", "Takes three cycles to dry", "Won't start" ],
  "Dishwasher" => [ "Not draining", "Dishes come out dirty", "Leaking at the door", "Won't start, lights blink" ],
  "Oven" => [ "Won't heat past 200°F", "Bake element sparked", "Door won't close fully" ],
  "Range" => [ "Burner won't ignite", "Clicking non-stop" ],
  "Microwave" => [ "Runs but doesn't heat", "Turntable stopped" ],
  "Ice maker" => [ "Not making ice", "Ice tastes bad, slow fill" ]
}
brands = %w[Whirlpool Samsung LG GE Frigidaire Maytag KitchenAid Bosch Kenmore]
tech_notes = [
  "Diagnosed a failed drain pump, replaced on site.", "Needs a new control board, part ordered, ETA 3 days.",
  "Cleaned condenser coils, cooling back to normal.", "Replaced door gasket. Tested, no leaks.",
  "Customer approved the estimate.", "Thermal fuse blown. Replaced and cleaned the vent line.",
  "Customer wasn't home, left a door tag.", "Igniter replaced, all burners light."
]

today = Time.zone.today
created = 0
booked = Hash.new { |h, k| h[k] = [] } # [tech_id, date] => start hours, so nobody is double-booked
customers.each do |customer|
  rand(1..4).times do
    # Weighted toward this week so the board looks like a working day.
    day = rand < 0.35 ? today + rand(-1..3) : today + rand(-60..7)
    appliance = problems.keys.sample
    tech, hour = techs.shuffle.product([ 8, 10, 12, 14, 16 ].shuffle).find { |t, h| booked[[ t.id, day ]].exclude?(h) }
    next unless tech

    booked[[ tech.id, day ]] << hour
    slot = Time.zone.local(day.year, day.month, day.day, hour)

    status =
      if day < today then rand < 0.88 ? :completed : :canceled
      elsif day == today
        # Follow the clock: earlier slots are done, the current one is being worked.
        minutes_in = (Time.current - slot) / 60
        if minutes_in > 120 then rand < 0.85 ? :completed : :in_progress
        elsif minutes_in > 0 then :in_progress
        elsif minutes_in > -45 then :en_route
        else :scheduled
        end
      else rand < 0.85 ? :scheduled : :unscheduled
      end

    attrs = {
      customer: customer, property: customer.properties.first, appliance: appliance, brand: brands.sample,
      model_number: ("#{('A'..'Z').to_a.sample(3).join}#{rand(1000..9999)}" if rand < 0.6),
      problem: problems[appliance].sample, source: customer.source, created_by: [ admin, dispatcher ].sample,
      priority: rand < 0.1 ? :urgent : :normal, duration_minutes: [ 60, 90, 120, 120 ].sample,
      status: status, created_at: slot - rand(1..5).days
    }
    attrs.merge!(technician: tech, scheduled_at: slot) unless status == :unscheduled
    attrs[:cancel_reason] = [ "Customer fixed it", "Went with another company", "Rescheduled, will call back" ].sample if status == :canceled
    attrs[:started_at] = slot + 10.minutes if status.in?(%i[in_progress completed])
    attrs[:completed_at] = slot + attrs[:duration_minutes].minutes if status == :completed

    job = Job.create!(attrs)
    created += 1
    if status.in?(%i[completed in_progress])
      job.notes.create!(user: tech, body: tech_notes.sample, created_at: attrs[:started_at] + 30.minutes)
    end
  end
end

# Invoices for finished work: most paid (cash, check, card on site, online),
# some still waiting, a few overdue. Prices are typical for the trade.
parts = {
  "Refrigerator" => [ [ "Defrost thermostat", 4_800 ], [ "Evaporator fan motor", 8_900 ], [ "Start relay", 3_900 ] ],
  "Washer" => [ [ "Drain pump", 7_900 ], [ "Door lock assembly", 9_400 ], [ "Shock absorbers (pair)", 6_200 ] ],
  "Dryer" => [ [ "Heating element", 8_400 ], [ "Thermal fuse", 2_900 ], [ "Drum belt", 3_400 ] ],
  "Dishwasher" => [ [ "Drain pump", 8_200 ], [ "Door gasket", 4_600 ], [ "Control board", 18_900 ] ],
  "Oven" => [ [ "Bake element", 6_900 ], [ "Temperature sensor", 5_400 ] ],
  "Range" => [ [ "Igniter", 5_900 ], [ "Spark module", 8_800 ] ],
  "Microwave" => [ [ "Magnetron", 12_900 ], [ "Turntable motor", 3_600 ] ],
  "Ice maker" => [ [ "Ice maker assembly", 14_900 ], [ "Water inlet valve", 6_400 ] ]
}
invoiced = 0

Job.completed.includes(:customer, :technician).find_each do |job|
  next if rand < 0.08 # a few completed jobs not billed yet

  done = job.completed_at
  invoice = job.create_invoice!(tax_rate_bps: Company.tax_rate_bps, due_on: done.to_date + Company.payment_terms_days,
                                created_at: done, notes: "90-day warranty on parts and labor.")
  invoice.items.create!(kind: :fee, description: "Diagnostic visit", quantity: 1, unit_price_cents: 8_900)
  if rand < 0.8
    name, price = parts.fetch(job.appliance, [ [ "Replacement part", 6_500 ] ]).sample
    invoice.items.create!(kind: :part, description: name, quantity: 1, unit_price_cents: price)
    invoice.items.create!(kind: :labor, description: "Repair labor", quantity: [ 1, 1, 1.5, 2 ].sample, unit_price_cents: 9_500)
  end
  invoice.reload.recalculate!
  invoice.update_columns(status: Invoice.statuses[:sent], sent_at: done + 10.minutes)

  unpaid = done > 3.days.ago ? rand < 0.4 : rand < 0.07
  unless unpaid
    method = %i[card_on_site card_on_site cash check online].sample
    paid_at = [ method == :online ? done + rand(2..48).hours : done + 15.minutes, 5.minutes.ago ].min
    invoice.payments.create!(amount_cents: invoice.total_cents, method: method, received_at: paid_at, recorded_by: (job.technician unless method == :online),
                             reference: (rand(1000..9999).to_s if method == :check),
                             gateway: ("simulated" if method == :online), gateway_id: ("sim_ch_#{SecureRandom.hex(8)}" if method == :online))
    invoice.update_columns(status: Invoice.statuses[:paid], paid_cents: invoice.total_cents, paid_at: paid_at)
  end
  invoiced += 1
end

# The texts those events would have produced, so the outbox has history.
Job.where(scheduled_at: 7.days.ago.beginning_of_day..).where.not(technician_id: nil)
   .where(status: %i[en_route in_progress completed]).includes(:customer, :technician, :invoice).find_each do |job|
  sent = ->(kind, at, **ctx) do
    OutboundMessage.create!(kind: kind.to_s, customer: job.customer, job: job, to: job.customer.phone, status: :simulated, provider: "simulated",
                            body: Messaging.body_for(kind, job: job, customer: job.customer, **ctx), send_at: at, sent_at: at)
  end
  sent.(:on_my_way, job.scheduled_at - 25.minutes)
  next unless job.completed?

  if (invoice = job.invoice)
    sent.(:invoice, invoice.sent_at, invoice: invoice)
    if (payment = invoice.payments.first)
      sent.(:receipt, payment.received_at, invoice: invoice, payment: payment)
    end
  end
  review_at = job.completed_at + Company.review_request_delay
  if review_at.past?
    sent.(:review_request, review_at)
  else
    OutboundMessage.create!(kind: "review_request", customer: job.customer, job: job, to: job.customer.phone, status: :scheduled,
                            body: Messaging.body_for(:review_request, job: job, customer: job.customer), send_at: review_at)
  end
end

# A believable audit trail: who moved today's jobs and when, plus a couple of
# failed sign-ins. Written directly because seeding runs with auditing off.
Job.where(scheduled_at: (today - 2).beginning_of_day..today.end_of_day).where.not(technician_id: nil).find_each do |job|
  steps = { "en_route" => -25, "in_progress" => 10, "completed" => job.duration_minutes }
  reached = %w[en_route in_progress completed].take(%w[scheduled en_route in_progress completed].index(job.status).to_i)
  previous = "scheduled"
  reached.each do |status|
    AuditLog.create!(action: "job.update", auditable: job, user: job.technician, ip_address: "10.0.0.#{job.technician_id}",
                     audited_changes: { "status" => [ previous, status ] }, created_at: job.scheduled_at + steps[status].minutes)
    previous = status
  end
end
[ [ admin, 9 ], [ dispatcher, 8 ], *techs.map { [ _1, 7 ] } ].each do |user, hour|
  AuditLog.create!(action: "session.sign_in", auditable: user, user: user, ip_address: "10.0.0.#{user.id}",
                   created_at: today.in_time_zone.change(hour: hour, min: rand(0..40)))
end
2.times do |i|
  AuditLog.create!(action: "session.failed", ip_address: "203.0.113.#{40 + i}", created_at: today.in_time_zone.change(hour: 3, min: 12 + i),
                   audited_changes: { "email_address" => [ nil, "admin@fielddesk.demo" ] })
end
end

Current.skip_audit = false
puts "Seeded #{User.count} users, #{Customer.count} customers, #{Job.count} jobs, #{Invoice.count} invoices, " \
     "#{OutboundMessage.count} texts. Password for every demo login: demo-password"
