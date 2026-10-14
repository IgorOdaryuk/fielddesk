require "test_helper"

class TenantIsolationTest < ActionDispatch::IntegrationTest
  test "a company never sees another company's records" do
    sign_in_as users(:dispatcher)

    get job_path(jobs(:bayside_job))
    assert_response :not_found

    get customer_path(customers(:bayside_customer))
    assert_response :not_found

    get jobs_path(q: "secret")
    assert_response :success
    assert_select "td", text: /J-90099/, count: 0

    get customers_path
    assert_no_match "Carl Coastal", response.body
  end

  test "each company sees only its own team and audit log" do
    sign_in_as users(:bayside_admin)

    get users_path
    assert_response :success
    assert_match "Bea Bayside", response.body
    assert_no_match "Dan Dispatch", response.body

    get jobs_path
    assert_match "J-90099", response.body
    assert_no_match "J-90001", response.body
  end

  test "records can't point at another company's records" do
    job = Job.new(customer: customers(:jane), property: properties(:jane_home), appliance: "Oven", problem: "x",
                  technician: ActsAsTenant.without_tenant { users(:bayside_admin) })
    assert_not job.valid?
  end

  test "queries without an account fail loudly instead of leaking" do
    ActsAsTenant.test_tenant = nil
    assert_raises(ActsAsTenant::Errors::NoTenantSet) { Job.count }
  end

  test "new records join the current account" do
    customer = Customer.create!(name: "New Person", phone: "813-555-0188")
    assert_equal accounts(:sunshine), customer.account
  end

  test "invoice tax and terms come from the company" do
    invoice = ActsAsTenant.with_tenant(accounts(:bayside)) { Invoice.open_for!(jobs(:bayside_job)) }
    assert_equal 700, invoice.tax_rate_bps
    assert_equal Date.current + 14, invoice.due_on
  end
end
