module Stripe
  # Creates a Stripe checkout session for payment
  #
  # Usage:
  #   result = Stripe::CreateCheckout.call(
  #     run_id: "abc123",
  #     origin: "https://example.com"
  #   )
  #
  #   if result.success?
  #     result.checkout_url  # => Stripe checkout URL
  #   else
  #     result.error         # => Error message
  #   end
  #
  class CreateCheckout
    include Interactor

    CHECKOUT_URL = "https://api.stripe.com/v1/checkout/sessions".freeze

    def call
      context.fail!(error: "Stripe is not configured.") unless configured?
      context.fail!(error: "Missing run_id.") if context.run_id.blank?
      context.fail!(error: "Missing origin.") if context.origin.blank?

      params = URI.encode_www_form({
        "mode" => "payment",
        "success_url" => "#{context.origin}/success?runId=#{context.run_id}",
        "cancel_url" => "#{context.origin}/?checkout=cancel&runId=#{context.run_id}",
        "line_items[0][price]" => ENV["STRIPE_PRICE_ID"],
        "line_items[0][quantity]" => "1",
        "client_reference_id" => context.run_id,
        "metadata[run_id]" => context.run_id
      })

      conn = Faraday.new do |f|
        f.adapter Faraday.default_adapter
      end

      response = conn.post(CHECKOUT_URL) do |req|
        req.headers["Authorization"] = "Bearer #{ENV['STRIPE_SECRET_KEY']}"
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.headers["Idempotency-Key"] = "checkout-#{context.run_id}"
        req.body = params
      end

      unless response.success?
        error_body = JSON.parse(response.body) rescue { "error" => { "message" => response.body } }
        Rails.logger.error "Stripe checkout error: #{error_body.dig('error', 'message')}"
        context.fail!(error: "Stripe checkout failed.")
      end

      data = JSON.parse(response.body)
      context.fail!(error: "Stripe checkout failed.") unless data["url"]

      context.checkout_url = data["url"]
    end

    private

    def configured?
      ENV["STRIPE_SECRET_KEY"].present? && ENV["STRIPE_PRICE_ID"].present?
    end
  end
end
