# Any query on a tenant model without a current account raises instead of
# silently returning every company's data. Code that must look across
# accounts (sign-in, payment links) says so with ActsAsTenant.without_tenant.
ActsAsTenant.configure do |config|
  config.require_tenant = true
end
