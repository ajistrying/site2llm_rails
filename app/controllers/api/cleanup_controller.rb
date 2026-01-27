module Api
  class CleanupController < BaseController
    before_action :authenticate_token

    def create
      deleted = LlmsRun.delete_expired
      render json: { deleted: deleted }
    end

    def show
      deleted = LlmsRun.delete_expired
      render json: { deleted: deleted }
    end

    private

    def authenticate_token
      return unauthorized unless ENV["CLEANUP_TOKEN"].present?

      auth_header = request.headers["Authorization"]
      token_param = params[:token]

      token_from_header = nil
      if auth_header.present?
        scheme, token = auth_header.split(" ", 2)
        token_from_header = token if scheme == "Bearer" && token.present?
      end

      valid_token = token_from_header || token_param
      unauthorized unless valid_token.present? && valid_token == ENV["CLEANUP_TOKEN"]
    end

    def unauthorized
      render json: { error: "Unauthorized." }, status: :unauthorized
    end
  end
end
