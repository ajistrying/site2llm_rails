require 'rails_helper'

RSpec.describe Llms::BuildPreview do
  describe '#call' do
    context 'with valid content' do
      let(:content) do
        <<~CONTENT
          # My Site

          This is the summary line.

          ## Pages

          - /about - About page
          - /contact - Contact page
          - /pricing - Pricing page
          - /features - Features page
        CONTENT
      end

      it 'splits content into visible and locked portions' do
        result = described_class.call(content: content)

        expect(result).to be_success
        expect(result.visible).to be_present
        expect(result.locked).to be_present
      end

      it 'shows approximately half the content as visible' do
        result = described_class.call(content: content)

        total_lines = content.split("\n").length
        visible_lines = result.visible.split("\n").length

        expect(visible_lines).to be >= (total_lines / 2.0).floor
      end

      it 'masks the locked portion with # characters' do
        result = described_class.call(content: content)

        # The locked portion should contain only # characters (excluding whitespace)
        locked_without_whitespace = result.locked.gsub(/\s/, '')
        expect(locked_without_whitespace).to match(/\A#+\z/)
      end

      it 'preserves whitespace structure in locked portion' do
        result = described_class.call(content: content)

        # Count lines in locked portion
        locked_lines = result.locked.split("\n")
        expect(locked_lines.length).to be > 0
      end
    end

    context 'with short content' do
      let(:short_content) do
        <<~CONTENT
          # Title
          Line 1
          Line 2
          Line 3
          Line 4
          Line 5
        CONTENT
      end

      it 'ensures at least MIN_LOCKED lines are locked' do
        result = described_class.call(content: short_content)

        locked_lines = result.locked.split("\n").reject(&:empty?)
        expect(locked_lines.length).to be >= described_class::MIN_LOCKED
      end
    end

    context 'with blank content' do
      it 'fails with an error' do
        result = described_class.call(content: '')

        expect(result).to be_failure
        expect(result.error).to eq('Content is required')
      end

      it 'fails when content is nil' do
        result = described_class.call(content: nil)

        expect(result).to be_failure
        expect(result.error).to eq('Content is required')
      end
    end

    context 'with single line content' do
      it 'handles single line appropriately' do
        result = described_class.call(content: '# Just a title')

        expect(result).to be_success
        # With just one line, visible should have some content
        expect(result.visible).to be_present
      end
    end
  end
end
