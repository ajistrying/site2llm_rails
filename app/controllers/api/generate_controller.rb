module Api
  class GenerateController < BaseController
    def create
      payload = json_payload
      return render json: { error: "Invalid JSON payload." }, status: :bad_request unless payload

      errors = Llms::Generate.validate(payload.symbolize_keys)
      return render json: { errors: errors }, status: :bad_request if errors.any?

      result = Llms::Generate.call(**payload.symbolize_keys)

      unless result.success?
        if result.error_class == Llms::Generate::CrawlUnavailableError
          return render json: { error: result.error }, status: :service_unavailable
        end
        return render json: { error: result.error || "Failed to generate llms.txt." }, status: :internal_server_error
      end

      run = LlmsRun.create_run(result.content)
      return render json: { error: "Failed to persist run." }, status: :internal_server_error unless run

      preview_result = Llms::BuildPreview.call(content: result.content)

      render json: {
        runId: run.id,
        preview: preview_result.visible,
        lockedPreview: preview_result.locked,
        mode: result.mode,
        payment: {
          provider: "Stripe Checkout",
          priceUsd: Llms::Generate::PRICE_USD,
          billing: "one-time",
          payAfter: true
        }
      }
    rescue StandardError => e
      Rails.logger.error "Generate error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      render json: { error: "Failed to generate llms.txt." }, status: :internal_server_error
    end
  end
end
