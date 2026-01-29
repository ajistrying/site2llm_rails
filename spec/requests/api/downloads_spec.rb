require 'rails_helper'

RSpec.describe 'Api::Downloads', type: :request do
  describe 'GET /api/download' do
    context 'with a valid paid run' do
      let!(:paid_run) { create(:llms_run, :paid, content: '# My Site Content') }

      it 'returns the content as a downloadable file' do
        get '/api/download', params: { runId: paid_run.id }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/plain')
        expect(response.headers['Content-Disposition']).to include('attachment; filename="llms.txt"')
        expect(response.headers['Cache-Control']).to eq('no-store')
        expect(response.body).to eq('# My Site Content')
      end
    end

    context 'with missing runId' do
      it 'returns a bad request error' do
        get '/api/download'

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to eq('Missing runId.')
      end
    end

    context 'with a nonexistent run' do
      it 'returns a not found error' do
        get '/api/download', params: { runId: 'nonexistent-id' }

        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq('Run not found.')
      end
    end

    context 'with an expired run' do
      let!(:expired_run) { create(:llms_run, :paid, :expired) }

      it 'returns a not found error' do
        get '/api/download', params: { runId: expired_run.id }

        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq('Run not found.')
      end
    end

    context 'with an unpaid run' do
      let!(:unpaid_run) { create(:llms_run) }

      it 'returns a payment required error' do
        get '/api/download', params: { runId: unpaid_run.id }

        expect(response).to have_http_status(:payment_required)
        expect(response.body).to eq('Payment required.')
      end
    end
  end
end
