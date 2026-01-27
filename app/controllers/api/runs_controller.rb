module Api
  class RunsController < BaseController
    def show
      run_id = params[:runId]
      return render json: { error: "Missing runId." }, status: :bad_request if run_id.blank?

      run = LlmsRun.find_active(run_id)
      return render json: { error: "Run not found." }, status: :not_found unless run

      render json: { runId: run_id, paid: run.paid? }
    end
  end
end
