require 'rails_helper'

RSpec.describe Stripe::CreateCheckout do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('STRIPE_SECRET_KEY').and_return('sk_test_123')
    allow(ENV).to receive(:[]).with('STRIPE_PRICE_ID').and_return('price_test_123')
  end

  describe '#call' do
    let(:run_id) { 'run_123' }
    let(:origin) { 'https://example.com' }

    context 'with valid parameters' do
      before do
        stub_stripe_checkout_success
      end

      it 'returns success with checkout URL' do
        result = described_class.call(run_id: run_id, origin: origin)

        expect(result).to be_success
        expect(result.checkout_url).to eq('https://checkout.stripe.com/c/pay/test_session')
      end

      it 'makes a request to Stripe API' do
        described_class.call(run_id: run_id, origin: origin)

        expect(WebMock).to have_requested(:post, 'https://api.stripe.com/v1/checkout/sessions')
          .with(headers: { 'Authorization' => 'Bearer sk_test_123' })
      end

      it 'includes correct success and cancel URLs' do
        described_class.call(run_id: run_id, origin: origin)

        expect(WebMock).to have_requested(:post, 'https://api.stripe.com/v1/checkout/sessions')
          .with { |req| req.body.include?("success_url=#{CGI.escape("#{origin}/success?runId=#{run_id}")}") }
      end

      it 'includes run_id in metadata' do
        described_class.call(run_id: run_id, origin: origin)

        expect(WebMock).to have_requested(:post, 'https://api.stripe.com/v1/checkout/sessions')
          .with { |req| req.body.include?("metadata%5Brun_id%5D=#{run_id}") }
      end
    end

    context 'when Stripe is not configured' do
      before do
        allow(ENV).to receive(:[]).with('STRIPE_SECRET_KEY').and_return(nil)
      end

      it 'fails with configuration error' do
        result = described_class.call(run_id: run_id, origin: origin)

        expect(result).to be_failure
        expect(result.error).to eq('Stripe is not configured.')
      end
    end

    context 'when STRIPE_PRICE_ID is missing' do
      before do
        allow(ENV).to receive(:[]).with('STRIPE_PRICE_ID').and_return(nil)
      end

      it 'fails with configuration error' do
        result = described_class.call(run_id: run_id, origin: origin)

        expect(result).to be_failure
        expect(result.error).to eq('Stripe is not configured.')
      end
    end

    context 'with missing run_id' do
      it 'fails with missing run_id error' do
        result = described_class.call(run_id: '', origin: origin)

        expect(result).to be_failure
        expect(result.error).to eq('Missing run_id.')
      end

      it 'fails when run_id is nil' do
        result = described_class.call(run_id: nil, origin: origin)

        expect(result).to be_failure
        expect(result.error).to eq('Missing run_id.')
      end
    end

    context 'with missing origin' do
      it 'fails with missing origin error' do
        result = described_class.call(run_id: run_id, origin: '')

        expect(result).to be_failure
        expect(result.error).to eq('Missing origin.')
      end
    end

    context 'when Stripe returns an error' do
      before do
        stub_stripe_checkout_failure
      end

      it 'fails with checkout error' do
        result = described_class.call(run_id: run_id, origin: origin)

        expect(result).to be_failure
        expect(result.error).to eq('Stripe checkout failed.')
      end
    end
  end
end
