require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:dispatcher) }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
    assert_not_nil @user.reload.last_sign_in_at
    assert_equal "session.sign_in", AuditLog.last.action
  end

  test "create with invalid credentials is logged without the password" do
    assert_difference -> { AuditLog.where(action: "session.failed").count } do
      post session_path, params: { email_address: @user.email_address, password: "wrong" }
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    assert_not_includes AuditLog.last.audited_changes.to_json, "wrong"
  end

  test "deactivated users cannot sign in" do
    post session_path, params: { email_address: users(:retired).email_address, password: "password" }
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "deactivating a user ends their open session" do
    sign_in_as users(:tech)
    users(:tech).update!(active: false)

    get my_jobs_path
    assert_redirected_to new_session_path
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
