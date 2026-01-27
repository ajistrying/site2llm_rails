module Api
  class GenerateController < BaseController
    def create
      payload = json_payload
      return render json: { error: "Invalid JSON payload." }, status: :bad_request unless payload

      errors = LlmsGenerator.validate(payload.symbolize_keys)
      return render json: { errors: errors }, status: :bad_request if errors.any?

      generator = LlmsGenerator.new(payload.symbolize_keys)
      result = generator.generate
      run = LlmsRun.create_run(result[:content])

      return render json: { error: "Failed to persist run." }, status: :internal_server_error unless run

      preview = PreviewBuilder.new(result[:content]).build

      render json: {
        runId: run.id,
        preview: preview[:visible],
        lockedPreview: preview[:locked],
        mode: result[:mode],
        payment: {
          provider: "Stripe Checkout",
          priceUsd: LlmsGenerator::PRICE_USD,
          billing: "one-time",
          payAfter: true
        }
      }
    rescue LlmsGenerator::CrawlUnavailableError => e
      render json: { error: e.message }, status: :service_unavailable
    rescue StandardError => e
      Rails.logger.error "Generate error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      render json: { error: "Failed to generate llms.txt." }, status: :internal_server_error
    end
  end
end
