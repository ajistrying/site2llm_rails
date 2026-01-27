module Api
  module Stripe
    class WebhooksController < BaseController
      def create
        unless ENV["STRIPE_WEBHOOK_SECRET"].present?
          return render json: { error: "Stripe webhook secret not configured." }, status: :internal_server_error
        end

        signature = request.headers["Stripe-Signature"]
        return render json: { error: "Missing Stripe signature." }, status: :bad_request if signature.blank?

        payload = request.body.read
        unless StripeService.verify_webhook(payload: payload, signature: signature)
          return render json: { error: "Invalid signature." }, status: :bad_request
        end

        event = JSON.parse(payload)

        if %w[checkout.session.completed checkout.session.async_payment_succeeded].include?(event["type"])
          session = event.dig("data", "object")
          payment_status = session&.dig("payment_status")

          if payment_status.nil? || payment_status == "paid"
            run_id = session&.dig("metadata", "run_id") || session&.dig("client_reference_id")
            if run_id.present?
              run = LlmsRun.find_by(id: run_id)
              run&.mark_paid!
            end
          end
        end

        render json: { received: true }
      rescue JSON::ParserError
        render json: { error: "Invalid JSON payload." }, status: :bad_request
      end
    end
  end
end
