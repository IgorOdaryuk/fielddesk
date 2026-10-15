require "ipaddr"

# Behind Railway, every request reaches Puma from Railway's edge proxy, so
# REMOTE_ADDR and the tail of X-Forwarded-For are proxy addresses. That made
# every visitor share one rate-limit bucket and filled the audit log with
# proxy IPs. Railway's edge overwrites X-Real-IP and X-Forwarded-For on every
# request (visitors can't spoof them) but doesn't publish proxy ranges for
# trusted_proxies, so we take the visitor's address straight from the edge.
class EdgeClientIp
  def initialize(app)
    @app = app
  end

  def call(env)
    if (ip = visitor_ip(env))
      env["REMOTE_ADDR"] = ip
      env.delete("HTTP_X_FORWARDED_FOR")
      env.delete("HTTP_CLIENT_IP")
    end
    @app.call(env)
  end

  private
    def visitor_ip(env)
      [ env["HTTP_X_REAL_IP"], env["HTTP_X_FORWARDED_FOR"].to_s.split(",").first ].each do |candidate|
        ip = candidate.to_s.strip
        return ip if ip.present? && valid_ip?(ip)
      end
      nil
    end

    def valid_ip?(ip)
      IPAddr.new(ip)
      true
    rescue IPAddr::InvalidAddressError
      false
    end
end
