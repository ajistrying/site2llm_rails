module Stripe
  # Verifies Stripe webhook signature and processes payment events
  #
  # Usage:
  #   result = Stripe::VerifyWebhook.call(
  #     payload: request.body.read,
  #     signature: request.headers["Stripe-Signature"]
  #   )
  #
  #   if result.success?
  #     result.valid       # => true if signature valid
  #     result.run_id      # => Run ID from checkout session (if applicable)
  #     result.event_type  # => Event type (e.g., "checkout.session.completed")
  #   else
  #     result.error       # => Error message
  #   end
  #
  class VerifyWebhook
    include Interactor

    TIMESTAMP_TOLERANCE = 300 # 5 minutes

    def call
      secret = ENV["STRIPE_WEBHOOK_SECRET"]
      context.fail!(error: "Stripe webhook secret not configured.") unless secret

      context.fail!(error: "Missing Stripe signature.") if context.signature.blank?
      context.fail!(error: "Missing payload.") if context.payload.blank?

      parsed = parse_signature(context.signature)
      unless parsed
        context.valid = false
        return
      end

      signed_payload = "#{parsed[:timestamp]}.#{context.payload}"
      expected_signature = OpenSSL::HMAC.hexdigest("SHA256", secret, signed_payload)

      timestamp_num = parsed[:timestamp].to_i
      age = (Time.now.to_i - timestamp_num).abs
      if age > TIMESTAMP_TOLERANCE
        context.valid = false
        return
      end

      signature_valid = parsed[:signatures].any? do |sig|
        ActiveSupport::SecurityUtils.secure_compare(sig, expected_signature)
      end

      context.valid = signature_valid
      return unless signature_valid

      # Parse event and extract run_id if applicable
      begin
        event = JSON.parse(context.payload)
        context.event_type = event["type"]

        if %w[checkout.session.completed checkout.session.async_payment_succeeded].include?(event["type"])
          session = event.dig("data", "object")
          payment_status = session&.dig("payment_status")

          if payment_status.nil? || payment_status == "paid"
            context.run_id = session&.dig("metadata", "run_id") || session&.dig("client_reference_id")
          end
        end
      rescue JSON::ParserError
        context.valid = false
      end
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
