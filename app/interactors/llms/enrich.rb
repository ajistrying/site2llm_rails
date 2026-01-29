module Llms
  # Enriches pages and questions using LLM (OpenAI)
  #
  # Expected context:
  # - input: Llms::Generate::SurveyInput (required)
  # - pages: Array of Llms::Generate::PageItem (required)
  #
  # Sets in context:
  # - pages: Enriched array of Llms::Generate::PageItem
  # - questions: String of questions (newline-separated)
  # - enrichment_used: Boolean indicating if LLM was used
  # - summary: String containing the enriched summary
  #
  class Enrich
    include Interactor

    MAX_PAGES = 12
    MAX_QUESTIONS = 6
    MAX_DESC_CHARS = 140
    MAX_TITLE_CHARS = 60
    MAX_SOURCE_CHARS = 400
    MAX_CONTENT_CHARS = 600
    REQUEST_TIMEOUT = 25

    STATIC_KEYWORDS = %w[
      pricing plans billing docs documentation api support faq changelog
      security integrations getting-started guides tutorials status contact
    ].freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You create content for llms.txt files - curated indexes that help AI assistants understand websites.

      Your task:
      1. Write a one-sentence summary (50-120 chars) that clearly states what this business does and who it helps. Be specific and factual, no marketing fluff.
      2. Generate 4-6 specific questions that someone would actually ask about this business - questions the site can answer.
      3. For each page URL, write a description (50-120 chars, max 140) explaining what a user can DO or LEARN there.

      Guidelines for descriptions:
      - Focus on user actions: "Create billing plans with usage-based pricing" not "Our billing solution"
      - Be specific: "Browse organic cotton socks in crew, ankle, and knee styles" not "Shop our products"
      - No marketing words: avoid "leading", "best-in-class", "comprehensive", "innovative"
      - Start with a verb when possible: "Learn", "Configure", "Browse", "Compare", "Get"

      Guidelines for questions:
      - Make them specific to this business's domain
      - Questions should be answerable by the site content
      - Bad: "What do you do?" Good: "How do I sync inventory between Shopify and Amazon?"
      - Include practical questions about pricing, setup, features, policies

      ## Example 1: SaaS Product

      Input:
      {"site":{"name":"Acme Sync","url":"https://acmesync.com","userDescription":"inventory sync software","siteType":"saas"},"pages":[{"url":"https://acmesync.com/pricing","title":"Pricing","currentDescription":""},{"url":"https://acmesync.com/features","title":"Features","currentDescription":""},{"url":"https://acmesync.com/docs/getting-started","title":"Getting Started","currentDescription":""},{"url":"https://acmesync.com/integrations","title":"Integrations","currentDescription":""}]}

      Output:
      {"summary":"Real-time inventory sync between Shopify, Amazon, and WooCommerce for e-commerce sellers.","questions":["How do I connect my Shopify store to Acme Sync?","What happens when inventory reaches zero across channels?","Does Acme Sync support multi-warehouse setups?","How much does Acme Sync cost per month?","Can I set up automatic low-stock alerts?"],"pages":[{"url":"https://acmesync.com/pricing","title":"Pricing","description":"Compare monthly plans and see per-channel pricing for inventory sync."},{"url":"https://acmesync.com/features","title":"Features","description":"See real-time sync, multi-warehouse support, and low-stock alerts in action."},{"url":"https://acmesync.com/docs/getting-started","title":"Getting Started","description":"Connect your first store and configure sync rules in under 10 minutes."},{"url":"https://acmesync.com/integrations","title":"Integrations","description":"Browse supported platforms including Shopify, Amazon, WooCommerce, and BigCommerce."}]}

      ## Example 2: E-commerce Store

      Input:
      {"site":{"name":"Green Thread Co","url":"https://greenthread.co","userDescription":"sustainable clothing","siteType":"ecommerce"},"pages":[{"url":"https://greenthread.co/collections/mens","title":"Men's Collection","currentDescription":""},{"url":"https://greenthread.co/pages/our-story","title":"Our Story","currentDescription":""},{"url":"https://greenthread.co/pages/sustainability","title":"Sustainability","currentDescription":""},{"url":"https://greenthread.co/pages/shipping","title":"Shipping","currentDescription":""}]}

      Output:
      {"summary":"Organic cotton basics and recycled activewear for environmentally conscious shoppers.","questions":["What certifications do your organic materials have?","How long does shipping take within the US?","Do you offer free returns on clothing?","What is your sizing like compared to standard US sizes?","Are your packaging materials also sustainable?"],"pages":[{"url":"https://greenthread.co/collections/mens","title":"Men's Collection","description":"Shop organic cotton tees, recycled polyester shorts, and sustainable basics for men."},{"url":"https://greenthread.co/pages/our-story","title":"Our Story","description":"Learn how we source materials and partner with ethical factories worldwide."},{"url":"https://greenthread.co/pages/sustainability","title":"Sustainability","description":"See our GOTS certification, carbon footprint data, and recycling programs."},{"url":"https://greenthread.co/pages/shipping","title":"Shipping & Returns","description":"View delivery times, costs, and our 30-day free return policy."}]}

      Now process the following input and return only valid JSON:
    PROMPT

    def call
      context.summary = context.input.summary
      context.questions = context.input.questions

      unless api_configured? && context.pages.any?
        context.enrichment_used = false
        return
      end

      candidates = select_candidate_pages
      response = call_openai(candidates)

      unless response
        context.enrichment_used = false
        return
      end

      parsed = parse_response(response)

      unless parsed
        context.enrichment_used = false
        return
      end

      # Use enriched summary if provided and better than user input
      if parsed["summary"].is_a?(String) && parsed["summary"].strip.length >= 30
        context.summary = parsed["summary"].strip
      end

      context.questions = merge_questions(parsed["questions"] || [])
      context.pages = merge_pages(parsed["pages"] || [])
      context.enrichment_used = true
    end

    private

    def api_configured?
      ENV["OPENAI_API_KEY"].present?
    end

    def select_candidate_pages
      keywords = build_keyword_set
      priority_set = build_url_set(context.input.priority_pages)
      optional_set = build_url_set(context.input.optional_pages)

      context.pages
        .each_with_index
        .map { |page, index| { page: page, index: index, score: score_page(page, keywords, priority_set, optional_set) } }
        .sort_by { |entry| [ -entry[:score], entry[:index] ] }
        .first(MAX_PAGES)
        .map { |entry| entry[:page] }
    end

    def build_keyword_set
      keywords = Set.new

      Llms::Generate.split_list(context.input.categories).each do |cat|
        keywords << cat.downcase
        keywords << slugify(cat)
      end

      Llms::Generate.split_list(context.input.questions).each do |question|
        question.downcase.split(/[^a-z0-9]+/).select { |t| t.length > 3 }.each do |token|
          keywords << token
        end
      end

      STATIC_KEYWORDS.each { |k| keywords << k }
      keywords.to_a.first(32)
    end

    def build_url_set(value)
      base_url = normalize_url(context.input.site_url)
      Llms::Generate.split_list(value)
        .filter_map { |entry| resolve_url(base_url, entry) }
        .map { |url| normalize_for_match(url) }
        .to_set
    end

    def normalize_url(value)
      trimmed = value.to_s.strip
      return "https://example.com" if trimmed.blank?
      trimmed.gsub(/\/+\z/, "")
    end

    def resolve_url(base_url, value)
      trimmed = value.to_s.strip
      return nil if trimmed.blank?
      URI.join(base_url + "/", trimmed).to_s
    rescue URI::InvalidURIError
      nil
    end

    def normalize_for_match(value)
      value.gsub(/\/+\z/, "").downcase
    end

    def score_page(page, keywords, priority_set, optional_set)
      key = normalize_for_match(page.url)
      score = 0
      score += 100 if priority_set.include?(key)
      score += 20 if optional_set.include?(key)

      haystack = "#{page.title} #{page.description} #{page.url}".downcase
      keywords.each { |keyword| score += 4 if keyword.present? && haystack.include?(keyword) }

      begin
        depth = URI.parse(page.url).path.split("/").reject(&:blank?).length
        score += [ 0, 6 - depth ].max
      rescue URI::InvalidURIError
        # Ignore
      end

      score
    end

    def slugify(value)
      value.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end

    def call_openai(candidates)
      base_url = (ENV["OPENAI_BASE_URL"] || "https://api.openai.com/v1").gsub(/\/\z/, "")
      chat_url = base_url.end_with?("/v1") ? "#{base_url}/chat/completions" : "#{base_url}/v1/chat/completions"
      model = ENV["OPENAI_MODEL"] || "gpt-4o-mini"

      payload = build_prompt_payload(candidates)

      conn = Faraday.new do |f|
        f.request :json
        f.response :json
        f.options.timeout = REQUEST_TIMEOUT
        f.adapter Faraday.default_adapter
      end

      response = conn.post(chat_url) do |req|
        req.headers["Authorization"] = "Bearer #{ENV['OPENAI_API_KEY']}"
        req.body = {
          model: model,
          temperature: 0.3,
          max_tokens: 2500,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: JSON.pretty_generate(payload) }
          ]
        }
      end

      return nil unless response.success?

      response.body.dig("choices", 0, "message", "content")
    rescue Faraday::Error => e
      Rails.logger.error "OpenAI request failed: #{e.message}"
      nil
    end

    def build_prompt_payload(pages)
      {
        site: {
          name: context.input.site_name,
          url: context.input.site_url,
          userDescription: context.input.summary,
          siteType: context.input.site_type
        },
        pages: pages.map do |page|
          entry = {
            url: page.url,
            title: trim_to(page.title, MAX_TITLE_CHARS),
            currentDescription: trim_to(page.description, MAX_SOURCE_CHARS)
          }
          # Include content preview if available for better descriptions
          if page.respond_to?(:content) && page.content.present?
            entry[:contentPreview] = trim_to(page.content, MAX_CONTENT_CHARS)
          end
          entry
        end
      }
    end

    def trim_to(value, max)
      clean = value.gsub(/\s+/, " ").strip
      return clean if clean.length <= max
      "#{clean[0, max - 1].strip}..."
    end

    def parse_response(value)
      JSON.parse(value)
    rescue JSON::ParserError
      start_idx = value.index("{")
      end_idx = value.rindex("}")
      return nil if start_idx.nil? || end_idx.nil?

      begin
        JSON.parse(value[start_idx..end_idx])
      rescue JSON::ParserError
        nil
      end
    end

    def merge_questions(extra)
      # Prefer LLM-generated questions as they're more specific
      llm_questions = extra
        .select { |v| v.is_a?(String) && v.strip.present? }
        .map(&:strip)
        .first(MAX_QUESTIONS)

      return llm_questions.join("\n") if llm_questions.length >= 4

      # Fall back to mixing with user questions if LLM didn't provide enough
      existing_list = Llms::Generate.split_list(context.input.questions)
      normalized = llm_questions.map { |v| v.downcase.gsub(/[^a-z0-9]+/, "") }.to_set

      additions = existing_list.reject do |v|
        key = v.downcase.gsub(/[^a-z0-9]+/, "")
        key.blank? || normalized.include?(key).tap { normalized << key }
      end

      (llm_questions + additions).first(MAX_QUESTIONS).join("\n")
    end

    def merge_pages(updates)
      merged = context.pages.map(&:dup)
      lookup = merged.index_by { |page| normalize_for_match(page.url) }

      updates.each do |update|
        next unless update["url"]
        target = lookup[normalize_for_match(update["url"])]
        next unless target

        if update["title"].is_a?(String) && update["title"].strip.present?
          target.title = trim_to(update["title"], MAX_TITLE_CHARS)
        end
        if update["description"].is_a?(String) && update["description"].strip.present?
          target.description = trim_to(update["description"], MAX_DESC_CHARS)
        end
      end

      merged
    end
  end
end
