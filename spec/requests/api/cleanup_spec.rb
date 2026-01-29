require 'rails_helper'

RSpec.describe 'Api::Cleanup', type: :request do
  let(:cleanup_token) { 'test_cleanup_token' }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CLEANUP_TOKEN').and_return(cleanup_token)
  end

  describe 'GET /api/cleanup' do
    context 'with valid Bearer token' do
      let!(:active_run) { create(:llms_run) }
      let!(:expired_run1) { create(:llms_run, :expired) }
      let!(:expired_run2) { create(:llms_run, :expired) }

      it 'deletes expired runs and returns count' do
        get '/api/cleanup', headers: { 'Authorization' => "Bearer #{cleanup_token}" }

        expect(response).to have_http_status(:ok)
        expect(json_response['deleted']).to eq(2)
      end

      it 'preserves active runs' do
        get '/api/cleanup', headers: { 'Authorization' => "Bearer #{cleanup_token}" }

        expect(LlmsRun.find_by(id: active_run.id)).to eq(active_run)
      end
    end

    context 'with valid token parameter' do
      let!(:expired_run) { create(:llms_run, :expired) }

      it 'authenticates via query param' do
        get '/api/cleanup', params: { token: cleanup_token }

        expect(response).to have_http_status(:ok)
        expect(json_response['deleted']).to eq(1)
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized' do
        get '/api/cleanup', headers: { 'Authorization' => 'Bearer invalid_token' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Unauthorized.')
      end
    end

    context 'with missing token' do
      it 'returns unauthorized' do
        get '/api/cleanup'

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Unauthorized.')
      end
    end

    context 'when CLEANUP_TOKEN is not configured' do
      before do
        allow(ENV).to receive(:[]).with('CLEANUP_TOKEN').and_return(nil)
      end

      it 'returns unauthorized' do
        get '/api/cleanup', headers: { 'Authorization' => "Bearer #{cleanup_token}" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with no expired runs' do
      let!(:active_run) { create(:llms_run) }

      it 'returns zero deleted count' do
        get '/api/cleanup', headers: { 'Authorization' => "Bearer #{cleanup_token}" }

        expect(response).to have_http_status(:ok)
        expect(json_response['deleted']).to eq(0)
      end
    end
  end

  describe 'POST /api/cleanup' do
    context 'with valid Bearer token' do
      let!(:expired_run) { create(:llms_run, :expired) }

      it 'deletes expired runs and returns count' do
        post '/api/cleanup', headers: { 'Authorization' => "Bearer #{cleanup_token}" }

        expect(response).to have_http_status(:ok)
        expect(json_response['deleted']).to eq(1)
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized' do
        post '/api/cleanup', headers: { 'Authorization' => 'Bearer invalid_token' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
