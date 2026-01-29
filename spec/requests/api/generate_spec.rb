require 'rails_helper'

RSpec.describe 'Api::Generate', type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('FIRECRAWL_API_KEY').and_return('test_firecrawl_key')
  end

  describe 'POST /api/generate' do
    let(:valid_params) do
      {
        site_name: 'Example Corp',
        site_url: 'https://example.com',
        summary: 'Example Corp provides enterprise solutions for modern businesses.',
        important_pages: "/pricing\n/about\n/features\n/contact"
      }
    end

    context 'with valid parameters' do
      before do
        stub_firecrawl_success
        stub_openai_success
      end

      it 'returns a successful response with runId and preview' do
        post_json '/api/generate', valid_params

        expect(response).to have_http_status(:ok)
        expect(json_response).to include('runId', 'preview', 'lockedPreview', 'mode', 'payment')
        expect(json_response['mode']).to eq('live')
        expect(json_response['payment']).to include(
          'provider' => 'Stripe Checkout',
          'priceUsd' => 8,
          'billing' => 'one-time',
          'payAfter' => true
        )
      end

      it 'creates a new LlmsRun record' do
        expect {
          post_json '/api/generate', valid_params
        }.to change(LlmsRun, :count).by(1)
      end

      it 'returns a preview with visible and locked portions' do
        post_json '/api/generate', valid_params

        expect(json_response['preview']).to be_present
        expect(json_response['lockedPreview']).to be_present
      end
    end

    context 'with invalid parameters' do
      it 'returns validation errors for missing site_name' do
        post_json '/api/generate', valid_params.except(:site_name)

        expect(response).to have_http_status(:bad_request)
        expect(json_response['errors']).to include('site_name')
      end

      it 'returns validation errors for missing site_url' do
        post_json '/api/generate', valid_params.except(:site_url)

        expect(response).to have_http_status(:bad_request)
        expect(json_response['errors']).to include('site_url')
      end

      it 'returns validation errors for invalid site_url' do
        post_json '/api/generate', valid_params.merge(site_url: 'not-a-url')

        expect(response).to have_http_status(:bad_request)
        expect(json_response['errors']).to include('site_url')
      end

      it 'returns validation errors for short summary' do
        post_json '/api/generate', valid_params.merge(summary: 'Too short')

        expect(response).to have_http_status(:bad_request)
        expect(json_response['errors']).to include('summary')
      end

      it 'returns validation errors for too few important pages' do
        post_json '/api/generate', valid_params.merge(important_pages: '/about')

        expect(response).to have_http_status(:bad_request)
        expect(json_response['errors']).to include('important_pages')
      end

      it 'returns validation errors for too many important pages' do
        too_many = (1..10).map { |i| "/page#{i}" }.join("\n")
        post_json '/api/generate', valid_params.merge(important_pages: too_many)

        expect(response).to have_http_status(:bad_request)
        expect(json_response['errors']).to include('important_pages')
      end
    end

    context 'with invalid JSON' do
      it 'returns a bad request error' do
        post '/api/generate', params: 'not json', headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']).to eq('Invalid JSON payload.')
      end
    end

    context 'when Firecrawl is unavailable' do
      before do
        stub_firecrawl_unavailable
      end

      it 'returns a service unavailable error' do
        post_json '/api/generate', valid_params

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
