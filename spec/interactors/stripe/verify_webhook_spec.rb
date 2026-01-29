require 'rails_helper'

RSpec.describe Stripe::VerifyWebhook do
  let(:webhook_secret) { 'whsec_test_secret' }
  let(:run_id) { 'run_123' }
  let(:event_type) { 'checkout.session.completed' }
  let(:timestamp) { Time.now.to_i }

  let(:payload) do
    {
      type: event_type,
      data: {
        object: {
          id: 'cs_test_123',
          payment_status: 'paid',
          metadata: { run_id: run_id },
          client_reference_id: run_id
        }
      }
    }.to_json
  end

  def generate_signature(payload, timestamp, secret)
    signed_payload = "#{timestamp}.#{payload}"
    signature = OpenSSL::HMAC.hexdigest('SHA256', secret, signed_payload)
    "t=#{timestamp},v1=#{signature}"
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('STRIPE_WEBHOOK_SECRET').and_return(webhook_secret)
  end

  describe '#call' do
    context 'with valid signature' do
      let(:signature) { generate_signature(payload, timestamp, webhook_secret) }

      it 'returns valid: true' do
        result = described_class.call(payload: payload, signature: signature)

        expect(result).to be_success
        expect(result.valid).to be true
      end

      it 'extracts run_id from metadata' do
        result = described_class.call(payload: payload, signature: signature)

        expect(result.run_id).to eq(run_id)
      end

      it 'extracts event_type' do
        result = described_class.call(payload: payload, signature: signature)

        expect(result.event_type).to eq(event_type)
      end
    end

    context 'with checkout.session.async_payment_succeeded event' do
      let(:async_event_type) { 'checkout.session.async_payment_succeeded' }
      let(:async_payload) do
        {
          type: async_event_type,
          data: {
            object: {
              id: 'cs_test_123',
              payment_status: 'paid',
              metadata: { run_id: run_id }
            }
          }
        }.to_json
      end
      let(:signature) { generate_signature(async_payload, timestamp, webhook_secret) }

      it 'extracts run_id from async payment events' do
        result = described_class.call(payload: async_payload, signature: signature)

        expect(result).to be_success
        expect(result.valid).to be true
        expect(result.run_id).to eq(run_id)
      end
    end

    context 'with invalid signature' do
      let(:signature) { "t=#{timestamp},v1=invalid_signature" }

      it 'returns valid: false' do
        result = described_class.call(payload: payload, signature: signature)

        expect(result).to be_success
        expect(result.valid).to be false
      end
    end

    context 'with expired timestamp' do
      let(:old_timestamp) { Time.now.to_i - 600 } # 10 minutes ago
      let(:signature) { generate_signature(payload, old_timestamp, webhook_secret) }

      it 'returns valid: false' do
        result = described_class.call(payload: payload, signature: signature)

        expect(result).to be_success
        expect(result.valid).to be false
      end
    end

    context 'with missing signature' do
      it 'fails with missing signature error' do
        result = described_class.call(payload: payload, signature: nil)

        expect(result).to be_failure
        expect(result.error).to eq('Missing Stripe signature.')
      end

      it 'fails when signature is blank' do
        result = described_class.call(payload: payload, signature: '')

        expect(result).to be_failure
        expect(result.error).to eq('Missing Stripe signature.')
      end
    end

    context 'with missing payload' do
      let(:signature) { generate_signature('', timestamp, webhook_secret) }

      it 'fails with missing payload error' do
        result = described_class.call(payload: nil, signature: signature)

        expect(result).to be_failure
        expect(result.error).to eq('Missing payload.')
      end

      it 'fails when payload is blank' do
        result = described_class.call(payload: '', signature: signature)

        expect(result).to be_failure
        expect(result.error).to eq('Missing payload.')
      end
    end

    context 'when webhook secret is not configured' do
      before do
        allow(ENV).to receive(:[]).with('STRIPE_WEBHOOK_SECRET').and_return(nil)
      end

      it 'fails with configuration error' do
        result = described_class.call(payload: payload, signature: 'any')

        expect(result).to be_failure
        expect(result.error).to eq('Stripe webhook secret not configured.')
      end
    end

    context 'with malformed signature header' do
      it 'returns valid: false for empty signature parts' do
        result = described_class.call(payload: payload, signature: 'malformed')

        expect(result).to be_success
        expect(result.valid).to be false
      end

      it 'returns valid: false for missing v1 signature' do
        result = described_class.call(payload: payload, signature: "t=#{timestamp}")

        expect(result).to be_success
        expect(result.valid).to be false
      end

      it 'returns valid: false for missing timestamp' do
        result = described_class.call(payload: payload, signature: 'v1=somesig')

        expect(result).to be_success
        expect(result.valid).to be false
      end
    end

    context 'with invalid JSON payload' do
      let(:invalid_payload) { 'not valid json' }
      let(:signature) { generate_signature(invalid_payload, timestamp, webhook_secret) }

      it 'returns valid: false' do
        result = described_class.call(payload: invalid_payload, signature: signature)

        expect(result).to be_success
        expect(result.valid).to be false
      end
    end

    context 'when payment_status is not paid' do
      let(:unpaid_payload) do
        {
          type: event_type,
          data: {
            object: {
              id: 'cs_test_123',
              payment_status: 'unpaid',
              metadata: { run_id: run_id }
            }
          }
        }.to_json
      end
      let(:signature) { generate_signature(unpaid_payload, timestamp, webhook_secret) }

      it 'does not extract run_id' do
        result = described_class.call(payload: unpaid_payload, signature: signature)

        expect(result).to be_success
        expect(result.valid).to be true
        expect(result.run_id).to be_nil
      end
    end

    context 'with client_reference_id fallback' do
      let(:fallback_payload) do
        {
          type: event_type,
          data: {
            object: {
              id: 'cs_test_123',
              payment_status: 'paid',
              metadata: {},
              client_reference_id: run_id
            }
          }
        }.to_json
      end
      let(:signature) { generate_signature(fallback_payload, timestamp, webhook_secret) }

      it 'falls back to client_reference_id when metadata is empty' do
        result = described_class.call(payload: fallback_payload, signature: signature)

        expect(result).to be_success
        expect(result.run_id).to eq(run_id)
      end
    end
  end
end
