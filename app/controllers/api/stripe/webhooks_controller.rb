module Api
  module Stripe
    class WebhooksController < BaseController
      def create
        payload = request.body.read
        signature = request.headers["Stripe-Signature"]

        result = ::Stripe::VerifyWebhook.call(payload: payload, signature: signature)

        unless result.success?
          status = result.error&.include?("not configured") ? :internal_server_error : :bad_request
          return render json: { error: result.error }, status: status
        end

        unless result.valid
          return render json: { error: "Invalid signature." }, status: :bad_request
        end

        if result.run_id.present?
          run = LlmsRun.find_by(id: result.run_id)
          run&.mark_paid!
        end

        render json: { received: true }
      end
    end
  end
end
