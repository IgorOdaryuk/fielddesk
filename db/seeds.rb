# Two fictional companies, so the demo shows that accounts can't see each
# other. All data comes from DemoData. Safe to run repeatedly.

if Account.exists? && ENV["RESEED"].blank?
  puts "Seeds skipped: data already present (RESEED=1 to rebuild)"
  return
end

if ENV["RESEED"].present?
  ActsAsTenant.without_tenant do
    [ OutboundMessage, Payment, InvoiceItem, Invoice, AuditLog, JobNote, Job, Property, Customer, Session, User ].each(&:delete_all)
    ActiveStorage::Attachment.delete_all
    Account.delete_all
  end
end

main = Account.create!(name: "Sunshine Appliance Repair", slug: "sunshine-appliance-repair", **Account.defaults)
DemoData.populate(main, customers: 140, seed: 42)

second = Account.create!(name: "Bayside Appliance Pros", slug: "bayside-appliance-pros", **Account.defaults,
                         phone: "+17275550199", address: "200 Harbor Blvd, Clearwater, FL 33755")
DemoData.populate(second, customers: 40, login_suffix: "bayside", seed: 7)

ActsAsTenant.without_tenant do
  puts "Seeded #{Account.count} companies, #{User.count} users, #{Customer.count} customers, #{Job.count} jobs, " \
       "#{Invoice.count} invoices, #{OutboundMessage.count} texts. Password for every demo login: #{DemoData::PASSWORD}"
end
