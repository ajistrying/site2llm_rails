module StubExternalServices
  # Stub Firecrawl API responses (uses /v1/crawl endpoint)
  def stub_firecrawl_success(pages: [])
    default_pages = [
      { url: 'https://example.com/', title: 'Example Corp', markdown: 'Welcome to Example Corp. We provide enterprise solutions for modern businesses. This is a detailed description of what we do and how we help our customers succeed.' },
      { url: 'https://example.com/about', title: 'About Us', markdown: 'Learn about our company history and mission. We have been serving customers since 2010 with innovative solutions.' },
      { url: 'https://example.com/pricing', title: 'Pricing', markdown: 'View our pricing plans and subscription options. We offer flexible pricing for teams of all sizes.' },
      { url: 'https://example.com/features', title: 'Features', markdown: 'Explore our product features. Advanced analytics, real-time monitoring, and seamless integrations.' },
      { url: 'https://example.com/contact', title: 'Contact', markdown: 'Get in touch with our team. We are here to help you succeed with our platform.' }
    ]

    response_pages = pages.presence || default_pages

    stub_request(:post, 'https://api.firecrawl.dev/v1/crawl')
      .to_return(
        status: 200,
        body: {
          success: true,
          data: response_pages.map do |page|
            {
              url: page[:url],
              metadata: { title: page[:title], description: page[:description] || '' },
              markdown: page[:markdown]
            }
          end
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_firecrawl_failure
    stub_request(:post, 'https://api.firecrawl.dev/v1/crawl')
      .to_return(
        status: 500,
        body: { success: false, error: 'Internal server error' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_firecrawl_unavailable
    stub_request(:post, 'https://api.firecrawl.dev/v1/crawl')
      .to_timeout
  end

  # Stub OpenAI API responses
  def stub_openai_success(response_content: nil)
    default_content = {
      pages: [
        { url: 'https://example.com/pricing', description: 'View pricing plans and subscription options' },
        { url: 'https://example.com/about', description: 'Learn about our company history and mission' }
      ],
      questions: [
        'What does Example Corp do?',
        'How much does it cost?'
      ]
    }

    content = response_content || default_content

    stub_request(:post, %r{https://api\.openai\.com/v1/chat/completions})
      .to_return(
        status: 200,
        body: {
          choices: [
            {
              message: {
                content: content.to_json
              }
            }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_openai_failure
    stub_request(:post, %r{https://api\.openai\.com/v1/chat/completions})
      .to_return(
        status: 500,
        body: { error: { message: 'Internal server error' } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Stub Stripe API responses
  def stub_stripe_checkout_success(checkout_url: 'https://checkout.stripe.com/c/pay/test_session')
    stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
      .to_return(
        status: 200,
        body: {
          id: 'cs_test_123',
          url: checkout_url,
          object: 'checkout.session'
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_stripe_checkout_failure
    stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
      .to_return(
        status: 400,
        body: {
          error: {
            type: 'invalid_request_error',
            message: 'Invalid price ID'
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end

RSpec.configure do |config|
  config.include StubExternalServices
end
