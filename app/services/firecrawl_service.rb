class FirecrawlService
  API_URL = "https://api.firecrawl.dev/v1/crawl".freeze
  MAX_PAGES = 40

  def initialize(input)
    @input = input
  end

  def crawl
    api_key = ENV["FIRECRAWL_API_KEY"]
    raise LlmsGenerator::CrawlUnavailableError, "Crawling is temporarily unavailable. Please try again later." unless api_key

    response = make_request(api_key)
    parse_response(response)
  end

  private

  def make_request(api_key)
    conn = Faraday.new do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end

    conn.post(API_URL) do |req|
      req.headers["Authorization"] = "Bearer #{api_key}"
      req.body = {
        url: @input.site_url,
        limit: MAX_PAGES,
        scrapeOptions: {
          formats: [ "markdown" ],
          onlyMainContent: true
        }
      }
    end
  rescue Faraday::Error => e
    Rails.logger.error "Firecrawl request failed: #{e.message}"
    raise LlmsGenerator::CrawlUnavailableError, "We could not crawl your site right now. Please try again."
  end

  def parse_response(response)
    unless response.success? && response.body["success"]
      raise LlmsGenerator::CrawlUnavailableError, "We could not crawl your site right now. Please try again."
    end

    categories = parse_categories
    excludes = parse_excludes

    (response.body["data"] || []).filter_map do |entry|
      url = entry["url"].to_s
      next if url.blank?
      next if excludes.any? { |exclude| url.include?(exclude) }

      LlmsGenerator::PageItem.new(
        section: guess_section(url, categories),
        title: to_sentence(entry.dig("metadata", "title") || url),
        url: url,
        description: extract_description(entry["markdown"], entry.dig("metadata", "description"))
      )
    end
  end

  def parse_categories
    LlmsGenerator.split_list(@input.categories)
  end

  def parse_excludes
    LlmsGenerator.split_list(@input.excludes)
  end

  def guess_section(url, categories)
    match = categories.find { |cat| url.include?(slugify(cat)) }
    match || categories.first || "Core documentation"
  end

  def slugify(value)
    value.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
  end

  def to_sentence(value)
    value.gsub(/\s+/, " ").strip
  end

  def extract_description(markdown, fallback)
    clean_fallback = to_sentence(fallback.to_s)
    return clean_fallback if clean_fallback.present?
    return "Summary not available." if markdown.blank?

    lines = markdown.split("\n").map(&:strip)
    candidate = lines.find do |line|
      line.present? && !line.start_with?("#") && !line.start_with?("```") && line.length > 20
    end

    candidate ? to_sentence(candidate)[0, 160] : "Summary not available."
  end
end
