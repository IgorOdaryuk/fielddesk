require "test_helper"

class EdgeClientIpTest < ActiveSupport::TestCase
  def remote_ip_for(headers)
    seen = nil
    app = ActionDispatch::RemoteIp.new(->(env) { seen = ActionDispatch::Request.new(env).remote_ip; [ 200, {}, [] ] })
    EdgeClientIp.new(app).call(Rack::MockRequest.env_for("/", { "REMOTE_ADDR" => "100.64.0.5" }.merge(headers)))
    seen
  end

  test "uses the address Railway's edge puts in X-Real-IP" do
    assert_equal "93.203.249.178", remote_ip_for("HTTP_X_REAL_IP" => "93.203.249.178", "HTTP_X_FORWARDED_FOR" => "93.203.249.178, 152.233.12.242")
  end

  test "falls back to the first X-Forwarded-For address" do
    assert_equal "93.203.249.178", remote_ip_for("HTTP_X_FORWARDED_FOR" => "93.203.249.178, 152.233.12.242")
  end

  test "ignores garbage and keeps the socket address" do
    assert_equal "100.64.0.5", remote_ip_for("HTTP_X_REAL_IP" => "not-an-ip")
  end
end
