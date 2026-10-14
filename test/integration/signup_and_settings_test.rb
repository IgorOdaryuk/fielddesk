require "test_helper"

class SignupAndSettingsTest < ActionDispatch::IntegrationTest
  setup { ENV["ALLOW_SIGNUPS"] = "1" }
  teardown { ENV.delete("ALLOW_SIGNUPS") }

  test "someone signs up a new company with sample data" do
    assert_difference -> { Account.count } do
      perform_enqueued_jobs only: LoadSampleDataJob do
        post signup_path, params: { signup: { company_name: "Acme Repair", name: "Ann Owner", email_address: "ann@acme.example.com",
                                            password: "long-password-1", sample_data: "1" } }
      end
    end
    assert_redirected_to dashboard_path

    account = Account.find_by!(name: "Acme Repair")
    assert_not account.sample_data_loading?
    ActsAsTenant.with_tenant(account) do
      assert User.find_by!(email_address: "ann@acme.example.com").admin?
      assert_equal 4, User.technicians.count
      assert_operator Job.count, :>, 10
    end
    # Sunshine's data is untouched.
    assert_equal 3, Job.count
  end

  test "sign up without sample data starts empty" do
    post signup_path, params: { signup: { company_name: "Empty Co", name: "Eve", email_address: "eve@empty.example.com",
                                          password: "long-password-1", sample_data: "0" } }
    account = Account.find_by!(name: "Empty Co")
    ActsAsTenant.with_tenant(account) { assert_equal 0, Job.count }
  end

  test "sign up rejects a taken email" do
    assert_no_difference -> { Account.count } do
      post signup_path, params: { signup: { company_name: "Dup", name: "D", email_address: "admin@example.com", password: "long-password-1" } }
    end
    assert_response :unprocessable_content
  end

  test "sign-ups are closed outside demo mode unless allowed" do
    ENV.delete("ALLOW_SIGNUPS")
    get new_signup_path
    assert_redirected_to new_session_path
  end

  test "admin edits company settings, which flow into new invoices" do
    sign_in_as users(:admin)
    patch account_path, params: { account: { name: "Sunshine Repair Co", tax_rate_percent: "6.5", payment_terms_days: "10" } }
    assert_redirected_to edit_account_path

    accounts(:sunshine).reload # the test tenant is the same cached object
    invoice = Invoice.open_for!(jobs(:tina_today))
    assert_equal 650, invoice.tax_rate_bps
    assert_equal Date.current + 10, invoice.due_on
  end

  test "dispatchers can't change company settings" do
    sign_in_as users(:dispatcher)
    patch account_path, params: { account: { name: "Hacked" } }
    assert_equal "Sunshine Appliance Repair", accounts(:sunshine).reload.name
  end

  test "review link must be a real web address" do
    account = accounts(:sunshine)
    [ "javascript:alert(1)", "https://", "not a url" ].each do |bad|
      account.review_url = bad
      assert_not account.valid?, bad
    end
    account.review_url = "https://g.page/r/abc/review"
    assert account.valid?
  end
end
