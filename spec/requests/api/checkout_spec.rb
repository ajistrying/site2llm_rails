require 'rails_helper'

RSpec.describe 'Api::Checkout', type: :request do
  around do |example|
    original_secret = ENV['STRIPE_SECRET_KEY']
    original_price = ENV['STRIPE_PRICE_ID']
    ENV['STRIPE_SECRET_KEY'] = 'sk_test_123'
    ENV['STRIPE_PRICE_ID'] = 'price_test_123'
    example.run
    ENV['STRIPE_SECRET_KEY'] = original_secret
    ENV['STRIPE_PRICE_ID'] = original_price
  end

  describe 'POST /api/checkout' do
    context 'with a valid unpaid run' do
      let!(:run) { create(:llms_run) }

      before do
        stub_stripe_checkout_success
      end

      it 'returns a checkout URL' do
        post_json '/api/checkout', { runId: run.id }


        expect(response).to have_http_status(:ok)
        expect(json_response['url']).to eq('https://checkout.stripe.com/c/pay/test_session')
      end
    end

    context 'with missing runId' do
      it 'returns a bad request error' do
        post_json '/api/checkout', {}

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']).to eq('Missing runId.')
      end
    end

    context 'with a nonexistent run' do
      it 'returns a not found error' do
        post_json '/api/checkout', { runId: 'nonexistent-id' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('Run not found.')
      end
    end

    context 'with an expired run' do
      let!(:expired_run) { create(:llms_run, :expired) }

      it 'returns a not found error' do
        post_json '/api/checkout', { runId: expired_run.id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('Run not found.')
      end
    end

    context 'with an already paid run' do
      let!(:paid_run) { create(:llms_run, :paid) }

      it 'returns a conflict error' do
        post_json '/api/checkout', { runId: paid_run.id }

        expect(response).to have_http_status(:conflict)
        expect(json_response['error']).to eq('Run is already paid.')
      end
    end

    context 'when Stripe is not configured' do
      let!(:run) { create(:llms_run) }

      around do |example|
        original_secret = ENV['STRIPE_SECRET_KEY']
        original_price = ENV['STRIPE_PRICE_ID']
        ENV['STRIPE_SECRET_KEY'] = nil
        ENV['STRIPE_PRICE_ID'] = nil
        example.run
        ENV['STRIPE_SECRET_KEY'] = original_secret
        ENV['STRIPE_PRICE_ID'] = original_price
      end

      it 'returns an internal server error' do
        post_json '/api/checkout', { runId: run.id }

        expect(response).to have_http_status(:internal_server_error)
        expect(json_response['error']).to eq('Stripe is not configured.')
      end
    end

    context 'when Stripe returns an error' do
      let!(:run) { create(:llms_run) }

      before do
        stub_stripe_checkout_failure
      end

      it 'returns a bad gateway error' do
        post_json '/api/checkout', { runId: run.id }

        expect(response).to have_http_status(:bad_gateway)
      end
    end

    context 'with invalid JSON' do
      it 'returns a bad request error' do
        post '/api/checkout', params: 'not json', headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']).to eq('Invalid JSON payload.')
      end
    end
  end
end
