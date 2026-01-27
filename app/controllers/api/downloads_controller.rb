module Api
  class DownloadsController < BaseController
    def show
      run_id = params[:runId]
      return render plain: "Missing runId.", status: :bad_request if run_id.blank?

      run = LlmsRun.find_active(run_id)
      return render plain: "Run not found.", status: :not_found unless run
      return render plain: "Payment required.", status: :payment_required unless run.paid?

      response.headers["Content-Type"] = "text/plain; charset=utf-8"
      response.headers["Content-Disposition"] = 'attachment; filename="llms.txt"'
      response.headers["Cache-Control"] = "no-store"

      render plain: run.content
    end
  end
end
