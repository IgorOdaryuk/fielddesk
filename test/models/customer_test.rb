require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "phone and email are encrypted at rest" do
    raw = Customer.connection.select_one("SELECT phone, email FROM customers WHERE id = #{customers(:jane).id}")

    assert_not_includes raw["phone"], "5550101"
    assert_not_includes raw["email"], "jane@"
    assert_equal "+18135550101", customers(:jane).phone
  end

  test "normalizes US phone numbers to E.164" do
    customer = Customer.create!(name: "Pat", phone: "1 (727) 555-0199")
    assert_equal "+17275550199", customer.phone
  end

  test "finds customers by any phone format, exact email, or partial name" do
    assert_equal [ customers(:jane) ], Customer.search("813.555.0101").to_a
    assert_equal [ customers(:jane) ], Customer.search("JANE@example.com").to_a
    assert_equal [ customers(:bob) ], Customer.search("smi").to_a
  end

  test "needs a phone or an email" do
    customer = Customer.new(name: "Nobody")
    assert_not customer.valid?
    assert_includes customer.errors[:base], "Add a phone number or an email"
  end

  test "audit log masks encrypted contact fields" do
    customers(:jane).update!(phone: "813-555-0177")
    entry = AuditLog.where(auditable: customers(:jane)).last

    assert_equal [ "[FILTERED]", "[FILTERED]" ], entry.audited_changes["phone"]
    assert_not_includes entry.audited_changes.to_json, "0177"
  end
end
