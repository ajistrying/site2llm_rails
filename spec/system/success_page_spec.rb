require 'rails_helper'

RSpec.describe 'Success Page', type: :system do
  before do
    driven_by(:rack_test)
  end

  describe 'visiting without a runId' do
    it 'redirects to home page' do
      visit success_path

      expect(page).to have_current_path(root_path)
    end
  end

  describe 'visiting with an invalid runId' do
    it 'redirects to home page' do
      visit success_path(runId: 'invalid-id')

      expect(page).to have_current_path(root_path)
    end
  end

  describe 'visiting with an expired run' do
    let!(:expired_run) { create(:llms_run, :expired) }

    it 'redirects to home page' do
      visit success_path(runId: expired_run.id)

      expect(page).to have_current_path(root_path)
    end
  end

  describe 'visiting with a paid run' do
    let!(:paid_run) { create(:llms_run, :paid, :with_long_content) }

    it 'displays the full content' do
      visit success_path(runId: paid_run.id)

      expect(page).to have_content('Thank you for your purchase')
      expect(page).to have_content('Ready to download')
      expect(page).to have_button('Download llms.txt')
      expect(page).to have_button('Copy to clipboard')
    end

    it 'displays the Run ID' do
      visit success_path(runId: paid_run.id)

      expect(page).to have_content("Run ID: #{paid_run.id}")
    end

    it 'displays next steps' do
      visit success_path(runId: paid_run.id)

      expect(page).to have_content('Next steps')
      expect(page).to have_content('Save the file as llms.txt')
      expect(page).to have_content('Upload to your website')
    end

    it 'displays the content preview' do
      visit success_path(runId: paid_run.id)

      expect(page).to have_css('.preview-text')
      expect(page).to have_content('Example Corp')
    end
  end

  describe 'visiting with an unpaid run' do
    let!(:unpaid_run) { create(:llms_run) }

    it 'shows payment pending status' do
      visit success_path(runId: unpaid_run.id)

      expect(page).to have_content('Confirming payment')
    end

    it 'displays the progress bar' do
      visit success_path(runId: unpaid_run.id)

      expect(page).to have_css('[data-success-target="progressBar"]')
    end
  end

  describe 'back to generation link' do
    let!(:paid_run) { create(:llms_run, :paid) }

    it 'has a link back to home page' do
      visit success_path(runId: paid_run.id)

      expect(page).to have_link('Back to generation page', href: '/')
    end
  end
end
