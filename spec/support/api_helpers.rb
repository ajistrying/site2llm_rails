module ApiHelpers
  def json_response
    JSON.parse(response.body)
  end

  def post_json(path, params = {})
    post path, params: params.to_json, headers: { 'Content-Type' => 'application/json' }
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
