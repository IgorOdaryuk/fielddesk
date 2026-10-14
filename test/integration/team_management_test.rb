require "test_helper"

class TeamManagementTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "admin adds a technician" do
    post users_path, params: { user: { name: "Newt", email_address: "newt@example.com", role: "technician",
                                       color: "#123456", password: "long-password-1", password_confirmation: "long-password-1" } }
    assert_redirected_to users_path
    assert User.find_by(email_address: "newt@example.com").technician?
  end

  test "admin deactivates a technician and their sessions end" do
    users(:tech).sessions.create!
    patch toggle_active_user_path(users(:tech))

    assert_not users(:tech).reload.active?
    assert_empty users(:tech).sessions
  end

  test "admin cannot deactivate themselves" do
    patch toggle_active_user_path(users(:admin))
    assert users(:admin).reload.active?
  end

  test "editing without a password keeps the old one" do
    patch user_path(users(:tech)), params: { user: { name: "Tina T.", password: "", password_confirmation: "" } }
    assert users(:tech).reload.authenticate("password")
    assert_equal "Tina T.", users(:tech).name
  end
end
