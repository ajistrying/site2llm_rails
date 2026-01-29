require 'rails_helper'

RSpec.describe 'Api::Stripe::Webhooks', type: :request do
  let(:webhook_secret) { 'whsec_test_secret' }
  let(:timestamp) { Time.now.to_i }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('STRIPE_WEBHOOK_SECRET').and_return(webhook_secret)
  end

  def generate_signature(payload, timestamp, secret)
    signed_payload = "#{timestamp}.#{payload}"
    signature = OpenSSL::HMAC.hexdigest('SHA256', secret, signed_payload)
    "t=#{timestamp},v1=#{signature}"
  end

  describe 'POST /api/stripe/webhook' do
    context 'with valid checkout.session.completed event' do
      let!(:run) { create(:llms_run) }
      let(:payload) do
        {
          type: 'checkout.session.completed',
          data: {
            object: {
              id: 'cs_test_123',
              payment_status: 'paid',
              metadata: { run_id: run.id }
            }
          }
        }.to_json
      end
      let(:signature) { generate_signature(payload, timestamp, webhook_secret) }

      it 'returns received: true' do
        post '/api/stripe/webhook',
             params: payload,
             headers: {
               'Content-Type' => 'application/json',
               'Stripe-Signature' => signature
             }

        expect(response).to have_http_status(:ok)
        expect(json_response['received']).to be true
      end

      it 'marks the run as paid' do
        expect {
          post '/api/stripe/webhook',
               params: payload,
               headers: {
                 'Content-Type' => 'application/json',
                 'Stripe-Signature' => signature
               }
        }.to change { run.reload.paid? }.from(false).to(true)
      end
    end

    context 'with checkout.session.async_payment_succeeded event' do
      let!(:run) { create(:llms_run) }
      let(:payload) do
        {
          type: 'checkout.session.async_payment_succeeded',
          data: {
            object: {
              id: 'cs_test_123',
              payment_status: 'paid',
              metadata: { run_id: run.id }
            }
          }
        }.to_json
      end
      let(:signature) { generate_signature(payload, timestamp, webhook_secret) }

      it 'marks the run as paid' do
        expect {
          post '/api/stripe/webhook',
               params: payload,
               headers: {
                 'Content-Type' => 'application/json',
                 'Stripe-Signature' => signature
               }
        }.to change { run.reload.paid? }.from(false).to(true)
      end
    end

    context 'with valid event but no run_id' do
      let(:payload) do
        {
          type: 'customer.created',
          data: {
            object: { id: 'cus_test_123' }
          }
        }.to_json
      end
      let(:signature) { generate_signature(payload, timestamp, webhook_secret) }

      it 'returns received: true without error' do
        post '/api/stripe/webhook',
             params: payload,
             headers: {
               'Content-Type' => 'application/json',
               'Stripe-Signature' => signature
             }

        expect(response).to have_http_status(:ok)
        expect(json_response['received']).to be true
      end
    end

    context 'with nonexistent run_id' do
      let(:payload) do
        {
          type: 'checkout.session.completed',
          data: {
            object: {
              id: 'cs_test_123',
              payment_status: 'paid',
              metadata: { run_id: 'nonexistent-id' }
            }
          }
        }.to_json
      end
      let(:signature) { generate_signature(payload, timestamp, webhook_secret) }

      it 'returns received: true without error' do
        post '/api/stripe/webhook',
             params: payload,
             headers: {
               'Content-Type' => 'application/json',
               'Stripe-Signature' => signature
             }

        expect(response).to have_http_status(:ok)
        expect(json_response['received']).to be true
      end
    end

    context 'with invalid signature' do
      let(:payload) { '{}' }
      let(:signature) { 't=123,v1=invalid' }

      it 'returns bad request with invalid signature error' do
        post '/api/stripe/webhook',
             params: payload,
             headers: {
               'Content-Type' => 'application/json',
               'Stripe-Signature' => signature
             }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']).to eq('Invalid signature.')
      end
    end

    context 'with missing signature' do
      let(:payload) { '{}' }

      it 'returns bad request' do
        post '/api/stripe/webhook',
             params: payload,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when webhook secret is not configured' do
      before do
        allow(ENV).to receive(:[]).with('STRIPE_WEBHOOK_SECRET').and_return(nil)
      end

      let(:payload) { '{}' }

      it 'returns internal server error' do
        post '/api/stripe/webhook',
             params: payload,
             headers: {
               'Content-Type' => 'application/json',
               'Stripe-Signature' => 'any'
             }

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
