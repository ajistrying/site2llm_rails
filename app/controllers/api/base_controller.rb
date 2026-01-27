module Api
  class BaseController < ApplicationController
    skip_before_action :verify_authenticity_token

    rescue_from StandardError do |e|
      Rails.logger.error "API Error: #{e.message}"
      render json: { error: "Internal server error." }, status: :internal_server_error
    end

    private

    def json_payload
      @json_payload ||= JSON.parse(request.body.read)
    rescue JSON::ParserError
      nil
    end
  end
end
