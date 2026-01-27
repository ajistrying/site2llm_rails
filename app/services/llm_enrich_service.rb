class LlmEnrichService
  MAX_PAGES = 18
  MAX_QUESTIONS = 4
  MAX_DESC_CHARS = 160
  MAX_TITLE_CHARS = 80
  MAX_SOURCE_CHARS = 220
  REQUEST_TIMEOUT = 12

  STATIC_KEYWORDS = %w[
    pricing plans billing docs documentation api support faq changelog
    security integrations getting-started guides tutorials status contact
  ].freeze

  def initialize(input, pages)
    @input = input
    @pages = pages
  end

  def enrich
    return fallback_result unless api_configured? && @pages.any?

    candidates = select_candidate_pages
    response = call_openai(candidates)

    return fallback_result unless response

    parsed = parse_response(response)
    return fallback_result unless parsed

    questions = merge_questions(parsed["questions"] || [])
    pages = merge_pages(parsed["pages"] || [])

    { pages: pages, questions: questions, used: true }
  end

  private

  def api_configured?
    ENV["OPENAI_API_KEY"].present?
  end

  def fallback_result
    { pages: @pages, questions: @input.questions, used: false }
  end

  def select_candidate_pages
    keywords = build_keyword_set
    priority_set = build_url_set(@input.priority_pages)
    optional_set = build_url_set(@input.optional_pages)

    @pages
      .each_with_index
      .map { |page, index| { page: page, index: index, score: score_page(page, keywords, priority_set, optional_set) } }
      .sort_by { |entry| [ -entry[:score], entry[:index] ] }
      .first(MAX_PAGES)
      .map { |entry| entry[:page] }
  end

  def build_keyword_set
    keywords = Set.new

    LlmsGenerator.split_list(@input.categories).each do |cat|
      keywords << cat.downcase
      keywords << slugify(cat)
    end

    LlmsGenerator.split_list(@input.questions).each do |question|
      question.downcase.split(/[^a-z0-9]+/).select { |t| t.length > 3 }.each do |token|
        keywords << token
      end
    end

    STATIC_KEYWORDS.each { |k| keywords << k }
    keywords.to_a.first(32)
  end

  def build_url_set(value)
    base_url = normalize_url(@input.site_url)
    LlmsGenerator.split_list(value)
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
        temperature: 0.2,
        max_tokens: 900,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: "You refine llms.txt inputs. Return JSON only. Provide up to 4 concise user questions and improved titles/descriptions for the provided URLs. Descriptions must be factual, <= 160 characters, and avoid marketing fluff."
          },
          {
            role: "user",
            content: JSON.pretty_generate(payload)
          }
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
        name: @input.site_name,
        url: @input.site_url,
        summary: @input.summary,
        categories: LlmsGenerator.split_list(@input.categories),
        siteType: @input.site_type,
        questions: LlmsGenerator.split_list(@input.questions)
      },
      pages: pages.map do |page|
        {
          url: page.url,
          title: trim_to(page.title, MAX_TITLE_CHARS),
          description: trim_to(page.description, MAX_SOURCE_CHARS)
        }
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
    existing_list = LlmsGenerator.split_list(@input.questions)
    normalized = existing_list.map { |v| v.downcase.gsub(/[^a-z0-9]+/, "") }.to_set

    additions = extra
      .select { |v| v.is_a?(String) && v.strip.present? }
      .map(&:strip)
      .reject do |v|
        key = v.downcase.gsub(/[^a-z0-9]+/, "")
        key.blank? || normalized.include?(key).tap { normalized << key }
      end

    (existing_list + additions).first(8).join("\n")
  end

  def merge_pages(updates)
    merged = @pages.map(&:dup)
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
