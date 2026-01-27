module Api
  class CheckoutController < BaseController
    def create
      payload = json_payload
      return render json: { error: "Invalid JSON payload." }, status: :bad_request unless payload

      run_id = payload["runId"]
      return render json: { error: "Missing runId." }, status: :bad_request if run_id.blank?

      unless StripeService.configured?
        return render json: { error: "Stripe is not configured." }, status: :internal_server_error
      end

      run = LlmsRun.find_active(run_id)
      return render json: { error: "Run not found." }, status: :not_found unless run
      return render json: { error: "Run is already paid." }, status: :conflict if run.paid?

      origin = "#{request.protocol}#{request.host_with_port}"
      url = StripeService.create_checkout_session(run_id: run_id, origin: origin)

      render json: { url: url }
    rescue StandardError => e
      Rails.logger.error "Checkout error: #{e.message}"
      render json: { error: "Stripe checkout failed.", details: e.message }, status: :bad_gateway
    end
  end
end
