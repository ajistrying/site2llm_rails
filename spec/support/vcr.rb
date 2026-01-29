require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Ignore localhost requests (for Capybara)
  config.ignore_localhost = true

  # Filter sensitive data
  config.filter_sensitive_data('<FIRECRAWL_API_KEY>') { ENV['FIRECRAWL_API_KEY'] }
  config.filter_sensitive_data('<STRIPE_SECRET_KEY>') { ENV['STRIPE_SECRET_KEY'] }
  config.filter_sensitive_data('<STRIPE_WEBHOOK_SECRET>') { ENV['STRIPE_WEBHOOK_SECRET'] }
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }

  # Allow WebMock stubs to work - VCR will only record when explicitly asked
  config.allow_http_connections_when_no_cassette = true
end
