class StripeService
  CHECKOUT_URL = "https://api.stripe.com/v1/checkout/sessions".freeze
  TIMESTAMP_TOLERANCE = 300 # 5 minutes

  class << self
    def create_checkout_session(run_id:, origin:)
      raise "Stripe is not configured." unless configured?

      params = URI.encode_www_form({
        "mode" => "payment",
        "success_url" => "#{origin}/success?runId=#{run_id}",
        "cancel_url" => "#{origin}/?checkout=cancel&runId=#{run_id}",
        "line_items[0][price]" => ENV["STRIPE_PRICE_ID"],
        "line_items[0][quantity]" => "1",
        "client_reference_id" => run_id,
        "metadata[run_id]" => run_id
      })

      conn = Faraday.new do |f|
        f.adapter Faraday.default_adapter
      end

      response = conn.post(CHECKOUT_URL) do |req|
        req.headers["Authorization"] = "Bearer #{ENV['STRIPE_SECRET_KEY']}"
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.headers["Idempotency-Key"] = "checkout-#{run_id}"
        req.body = params
      end

      unless response.success?
        error_body = JSON.parse(response.body) rescue { "error" => { "message" => response.body } }
        Rails.logger.error "Stripe checkout error: #{error_body.dig('error', 'message')}"
        raise "Stripe checkout failed."
      end

      data = JSON.parse(response.body)
      raise "Stripe checkout failed." unless data["url"]

      data["url"]
    end

    def verify_webhook(payload:, signature:)
      secret = ENV["STRIPE_WEBHOOK_SECRET"]
      raise "Stripe webhook secret not configured." unless secret

      parsed = parse_signature(signature)
      return false unless parsed

      signed_payload = "#{parsed[:timestamp]}.#{payload}"
      expected_signature = OpenSSL::HMAC.hexdigest("SHA256", secret, signed_payload)

      timestamp_num = parsed[:timestamp].to_i
      age = (Time.now.to_i - timestamp_num).abs
      return false if age > TIMESTAMP_TOLERANCE

      parsed[:signatures].any? { |sig| ActiveSupport::SecurityUtils.secure_compare(sig, expected_signature) }
    end

    def configured?
      ENV["STRIPE_SECRET_KEY"].present? && ENV["STRIPE_PRICE_ID"].present?
    end

    private

    def parse_signature(header)
      return nil if header.blank?

      parts = header.split(",")
      timestamp_part = parts.find { |p| p.start_with?("t=") }
      signature_parts = parts.select { |p| p.start_with?("v1=") }

      return nil if timestamp_part.blank? || signature_parts.empty?

      timestamp = timestamp_part.split("=")[1]
      signatures = signature_parts.map { |p| p.split("=")[1] }

      return nil if timestamp.blank?

      { timestamp: timestamp, signatures: signatures }
    end
  end
end
