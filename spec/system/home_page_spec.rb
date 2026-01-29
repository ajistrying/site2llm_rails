require 'rails_helper'

RSpec.describe 'Home Page', type: :system do
  before do
    driven_by(:rack_test)
  end

  describe 'visiting the home page' do
    it 'displays the main heading' do
      visit root_path

      expect(page).to have_content('Make AI search read your site correctly')
    end

    it 'displays the price' do
      visit root_path

      expect(page).to have_content('$8')
    end

    it 'displays the survey form' do
      visit root_path

      expect(page).to have_css('[data-controller="survey"]')
      expect(page).to have_field('site_name')
      expect(page).to have_field('site_url')
      expect(page).to have_field('summary')
    end

    it 'displays value propositions' do
      visit root_path

      expect(page).to have_content('Fix AI misreads')
      expect(page).to have_content('Show up in AI search')
      expect(page).to have_content('One-time payment')
    end

    it 'displays how it works section' do
      visit root_path

      expect(page).to have_content('How it works')
      expect(page).to have_content('Tell us about your site')
      expect(page).to have_content('We crawl and generate intelligently')
      expect(page).to have_content('Preview, pay once, and publish')
    end

    it 'has the Generate llms.txt button' do
      visit root_path

      expect(page).to have_button('Generate llms.txt')
    end

    it 'has the Re-download with Run ID button' do
      visit root_path

      expect(page).to have_button('Re-download with Run ID')
    end
  end

  describe 'survey form structure' do
    before do
      visit root_path
    end

    it 'has Step 1 fields visible by default' do
      within('[data-step="1"]') do
        expect(page).to have_content('Your site')
        expect(page).to have_field('site_name')
        expect(page).to have_field('site_url')
        expect(page).to have_field('summary')
      end
    end

    it 'has Step 2 for important pages' do
      expect(page).to have_content('Important pages')
    end
  end

  describe 'publish steps section' do
    before do
      visit root_path
    end

    it 'displays publish instructions' do
      expect(page).to have_content('Publish steps')
      expect(page).to have_content('Make it live in three steps')
      expect(page).to have_content('Save the file as llms.txt')
      expect(page).to have_content('Upload to your public root')
    end
  end
end
