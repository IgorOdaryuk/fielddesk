require "net/http"

module SmsProviders
  # Plain HTTPS call to the Twilio Messages API; no SDK needed for one endpoint.
  class Twilio
    Error = Class.new(StandardError)

    def initialize(account_sid:, auth_token:, from:)
      @account_sid, @auth_token, @from = account_sid, auth_token, from
    end

    def name = "twilio"

    def deliver(message)
      uri = URI("https://api.twilio.com/2010-04-01/Accounts/#{@account_sid}/Messages.json")
      request = Net::HTTP::Post.new(uri)
      request.basic_auth(@account_sid, @auth_token)
      request.set_form_data("To" => message.to, "From" => @from, "Body" => message.body)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { _1.request(request) }
      body = JSON.parse(response.body) rescue {}
      raise Error, body["message"] || "Twilio returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      { status: :sent, provider_id: body["sid"] }
    end
  end
end
