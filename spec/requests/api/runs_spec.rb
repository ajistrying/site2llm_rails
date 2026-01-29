require 'rails_helper'

RSpec.describe 'Api::Runs', type: :request do
  describe 'GET /api/run' do
    context 'with a valid active run' do
      let!(:run) { create(:llms_run) }

      it 'returns run status with paid: false' do
        get '/api/run', params: { runId: run.id }

        expect(response).to have_http_status(:ok)
        expect(json_response['runId']).to eq(run.id)
        expect(json_response['paid']).to be false
      end
    end

    context 'with a paid run' do
      let!(:paid_run) { create(:llms_run, :paid) }

      it 'returns run status with paid: true' do
        get '/api/run', params: { runId: paid_run.id }

        expect(response).to have_http_status(:ok)
        expect(json_response['runId']).to eq(paid_run.id)
        expect(json_response['paid']).to be true
      end
    end

    context 'with missing runId' do
      it 'returns a bad request error' do
        get '/api/run'

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']).to eq('Missing runId.')
      end
    end

    context 'with a nonexistent run' do
      it 'returns a not found error' do
        get '/api/run', params: { runId: 'nonexistent-id' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('Run not found.')
      end
    end

    context 'with an expired run' do
      let!(:expired_run) { create(:llms_run, :expired) }

      it 'returns a not found error' do
        get '/api/run', params: { runId: expired_run.id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('Run not found.')
      end
    end
  end
end
