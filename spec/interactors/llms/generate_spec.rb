require 'rails_helper'

RSpec.describe Llms::Generate do
  describe '.validate' do
    let(:valid_params) do
      {
        site_name: 'Example Corp',
        site_url: 'https://example.com',
        summary: 'Example Corp provides enterprise solutions for modern businesses.',
        important_pages: "/pricing\n/about\n/features\n/contact"
      }
    end

    context 'with valid parameters' do
      it 'returns no errors' do
        errors = described_class.validate(valid_params)
        expect(errors).to be_empty
      end
    end

    context 'with missing site_name' do
      it 'returns an error for site_name' do
        errors = described_class.validate(valid_params.merge(site_name: ''))
        expect(errors[:site_name]).to be_present
      end
    end

    context 'with missing site_url' do
      it 'returns an error for site_url' do
        errors = described_class.validate(valid_params.merge(site_url: ''))
        expect(errors[:site_url]).to be_present
      end
    end

    context 'with invalid site_url' do
      it 'returns an error for non-http URLs' do
        errors = described_class.validate(valid_params.merge(site_url: 'ftp://example.com'))
        expect(errors[:site_url]).to include('http or https')
      end

      it 'returns an error for malformed URLs' do
        errors = described_class.validate(valid_params.merge(site_url: 'not a url at all'))
        expect(errors[:site_url]).to be_present
      end
    end

    context 'with short summary' do
      it 'returns an error when summary is less than 20 characters' do
        errors = described_class.validate(valid_params.merge(summary: 'Too short'))
        expect(errors[:summary]).to include('20+')
      end
    end

    context 'with invalid important_pages count' do
      it 'returns an error when fewer than 3 pages' do
        errors = described_class.validate(valid_params.merge(important_pages: '/page1'))
        expect(errors[:important_pages]).to include('3-8')
      end

      it 'returns an error when more than 8 pages' do
        too_many = (1..10).map { |i| "/page#{i}" }.join("\n")
        errors = described_class.validate(valid_params.merge(important_pages: too_many))
        expect(errors[:important_pages]).to include('3-8')
      end

      it 'accepts exactly 3 pages' do
        errors = described_class.validate(valid_params.merge(important_pages: "/p1\n/p2\n/p3"))
        expect(errors[:important_pages]).to be_nil
      end

      it 'accepts exactly 8 pages' do
        pages = (1..8).map { |i| "/page#{i}" }.join("\n")
        errors = described_class.validate(valid_params.merge(important_pages: pages))
        expect(errors[:important_pages]).to be_nil
      end
    end
  end

  describe '.normalize_params' do
    it 'strips whitespace from inputs' do
      params = { site_name: '  Example Corp  ', site_url: '  https://example.com  ' }
      normalized = described_class.normalize_params(params)

      expect(normalized[:site_name]).to eq('Example Corp')
      expect(normalized[:site_url]).to eq('https://example.com')
    end

    it 'maps important_pages to priority_pages' do
      params = { important_pages: '/pricing, /about' }
      normalized = described_class.normalize_params(params)

      expect(normalized[:priority_pages]).to eq('/pricing, /about')
    end

    it 'adds https:// to URLs without a scheme' do
      params = { site_url: 'example.com' }
      normalized = described_class.normalize_params(params)

      expect(normalized[:site_url]).to eq('https://example.com')
    end

    it 'preserves http:// URLs' do
      params = { site_url: 'http://example.com' }
      normalized = described_class.normalize_params(params)

      expect(normalized[:site_url]).to eq('http://example.com')
    end
  end

  describe '.split_list' do
    it 'splits by newlines' do
      result = described_class.split_list("/page1\n/page2\n/page3")
      expect(result).to eq(%w[/page1 /page2 /page3])
    end

    it 'splits by commas' do
      result = described_class.split_list('/page1, /page2, /page3')
      expect(result).to eq(%w[/page1 /page2 /page3])
    end

    it 'handles mixed delimiters' do
      result = described_class.split_list("/page1\n/page2, /page3")
      expect(result).to eq(%w[/page1 /page2 /page3])
    end

    it 'strips whitespace' do
      result = described_class.split_list('  /page1  ,  /page2  ')
      expect(result).to eq(%w[/page1 /page2])
    end

    it 'filters out blank entries' do
      result = described_class.split_list("/page1\n\n/page2")
      expect(result).to eq(%w[/page1 /page2])
    end

    it 'filters out "none" values' do
      result = described_class.split_list("/page1\nnone\n/page2")
      expect(result).to eq(%w[/page1 /page2])
    end

    it 'returns empty array for blank input' do
      expect(described_class.split_list('')).to eq([])
      expect(described_class.split_list(nil)).to eq([])
    end
  end

  describe '.infer_site_type' do
    it 'returns "docs" for documentation sites' do
      expect(described_class.infer_site_type(site_url: 'https://docs.example.com')).to eq('docs')
      expect(described_class.infer_site_type(summary: 'API documentation for developers')).to eq('docs')
    end

    it 'returns "ecommerce" for e-commerce sites' do
      expect(described_class.infer_site_type(summary: 'Shop for products online')).to eq('ecommerce')
      expect(described_class.infer_site_type(site_url: 'https://shop.example.com')).to eq('ecommerce')
    end

    it 'returns "saas" for SaaS products' do
      expect(described_class.infer_site_type(summary: 'SaaS platform for teams')).to eq('saas')
      expect(described_class.infer_site_type(summary: 'Software dashboard for analytics')).to eq('saas')
    end

    it 'returns "services" for service businesses' do
      expect(described_class.infer_site_type(summary: 'Consulting agency for startups')).to eq('services')
    end

    it 'returns "education" for educational sites' do
      expect(described_class.infer_site_type(summary: 'Learn to code with our courses')).to eq('education')
      expect(described_class.infer_site_type(site_url: 'https://academy.example.com')).to eq('education')
    end

    it 'returns "media" for media sites' do
      expect(described_class.infer_site_type(site_url: 'https://blog.example.com')).to eq('media')
    end

    it 'returns explicit site_type if provided' do
      expect(described_class.infer_site_type(site_type: 'docs')).to eq('docs')
    end

    it 'defaults to "marketing" when no match' do
      expect(described_class.infer_site_type(summary: 'General company website')).to eq('marketing')
    end
  end

  describe '#call' do
    let(:valid_params) do
      {
        site_name: 'Example Corp',
        site_url: 'https://example.com',
        summary: 'Example Corp provides enterprise solutions for modern businesses.',
        priority_pages: "/pricing\n/about\n/features\n/contact"
      }
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FIRECRAWL_API_KEY').and_return('test_firecrawl_key')
    end

    context 'with successful API calls' do
      before do
        stub_firecrawl_success
        stub_openai_success
      end

      it 'returns success with content and mode' do
        result = described_class.call(**valid_params)

        expect(result).to be_success
        expect(result.content).to be_present
        expect(result.mode).to eq('live')
      end
    end

    context 'when Firecrawl is unavailable' do
      before do
        stub_firecrawl_unavailable
      end

      it 'fails with CrawlUnavailableError' do
        result = described_class.call(**valid_params)

        expect(result).to be_failure
        expect(result.error_class).to eq(described_class::CrawlUnavailableError)
      end
    end
  end
end
