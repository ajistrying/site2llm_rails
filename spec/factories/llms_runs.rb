FactoryBot.define do
  factory :llms_run do
    content { "# My Site\n\nThis is a test llms.txt file.\n\n## Pages\n\n- /about - About page\n- /contact - Contact page" }
    expires_at { 24.hours.from_now }
    paid_at { nil }

    trait :paid do
      paid_at { Time.current }
      expires_at { 30.days.from_now }
    end

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :with_long_content do
      content do
        <<~CONTENT
          # Example Corp

          Example Corp provides enterprise solutions for modern businesses.

          ## Key Pages

          - /pricing - Pricing and plans
          - /features - Product features
          - /about - About our company
          - /contact - Contact us

          ## Documentation

          - /docs/getting-started - Getting started guide
          - /docs/api - API reference
          - /docs/faq - Frequently asked questions

          ## Questions

          - What does Example Corp do?
          - How much does it cost?
          - How do I get started?
        CONTENT
      end
    end
  end
end
