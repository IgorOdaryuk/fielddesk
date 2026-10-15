require "test_helper"

# The seeded demo companies share one published password. A visitor signed in
# as their admin must not be able to lock the next visitor out.
class SharedDemoTest < ActionDispatch::IntegrationTest
  setup do
    ENV["DEMO_MODE"] = "1"
    sign_in_as users(:admin)
  end
  teardown { ENV.delete("DEMO_MODE") }

  test "admin of the shared demo cannot change someone's password" do
    patch user_path(users(:tech)), params: { user: { name: users(:tech).name, password: "new-password-1", password_confirmation: "new-password-1" } }

    assert_redirected_to root_path
    assert users(:tech).reload.authenticate("password")
  end

  test "admin of the shared demo cannot deactivate or add people" do
    patch toggle_active_user_path(users(:tech))
    assert users(:tech).reload.active?

    assert_no_difference -> { User.count } do
      post users_path, params: { user: { name: "Newt", email_address: "newt@example.com", role: "technician",
                                         color: "#123456", password: "long-password-1", password_confirmation: "long-password-1" } }
    end
  end

  test "admin of the shared demo cannot change company settings but can view them" do
    get edit_account_path
    assert_response :success

    patch account_path, params: { account: { name: "Hacked", booking_enabled: "0" } }
    assert_equal "Sunshine Appliance Repair", accounts(:sunshine).reload.name
  end

  test "a sandbox company keeps full control of its team" do
    accounts(:sunshine).update!(sandbox: true)

    patch toggle_active_user_path(users(:tech))
    assert_not users(:tech).reload.active?
  end

  test "outside demo mode the team is editable as usual" do
    ENV.delete("DEMO_MODE")

    patch toggle_active_user_path(users(:tech))
    assert_not users(:tech).reload.active?
  end
end
