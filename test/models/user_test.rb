require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "stores only a bcrypt hash of the password" do
    user = User.create!(name: "New Person", email_address: "new@example.com", password: "correct-horse-battery")
    assert user.password_digest.start_with?("$2a$")
    assert_not_includes user.password_digest, "correct-horse-battery"
    assert user.authenticate("correct-horse-battery")
  end

  test "requires passwords of at least 10 characters" do
    user = User.new(name: "Short", email_address: "s@example.com", password: "123456789")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 10 characters)"
  end

  test "audit entries never contain the password digest" do
    Current.session = users(:admin).sessions.create!
    user = User.create!(name: "Logged", email_address: "logged@example.com", password: "a-secret-password")
    entry = AuditLog.where(auditable: user).last

    assert_equal "user.create", entry.action
    assert_equal [ "[FILTERED]", "[FILTERED]" ], entry.audited_changes["password_digest"]
    assert_equal users(:admin), entry.user
  end
end
