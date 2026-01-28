module Llms
  # Crawls website pages using Firecrawl API
  #
  # Expected context:
  # - input: Llms::Generate::SurveyInput (required)
  #
  # Sets in context:
  # - pages: Array of Llms::Generate::PageItem
  #
  class Crawl
    include Interactor

    API_URL = "https://api.firecrawl.dev/v1/crawl".freeze
    MAX_PAGES = 40

    def call
      api_key = ENV["FIRECRAWL_API_KEY"]
      unless api_key
        context.fail!(
          error: "Crawling is temporarily unavailable. Please try again later.",
          error_class: Llms::Generate::CrawlUnavailableError
        )
      end

      response = make_request(api_key)
      context.pages = parse_response(response)
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
          url: context.input.site_url,
          limit: MAX_PAGES,
          scrapeOptions: {
            formats: [ "markdown" ],
            onlyMainContent: true
          }
        }
      end
    rescue Faraday::Error => e
      Rails.logger.error "Firecrawl request failed: #{e.message}"
      context.fail!(
        error: "We could not crawl your site right now. Please try again.",
        error_class: Llms::Generate::CrawlUnavailableError
      )
    end

    def parse_response(response)
      unless response.success? && response.body["success"]
        context.fail!(
          error: "We could not crawl your site right now. Please try again.",
          error_class: Llms::Generate::CrawlUnavailableError
        )
      end

      categories = parse_categories
      excludes = parse_excludes

      (response.body["data"] || []).filter_map do |entry|
        url = entry["url"].to_s
        next if url.blank?
        next if excludes.any? { |exclude| url.include?(exclude) }

        markdown = entry["markdown"].to_s

        Llms::Generate::PageItem.new(
          section: guess_section(url, categories),
          title: to_sentence(entry.dig("metadata", "title") || url),
          url: url,
          description: extract_description(markdown, entry.dig("metadata", "description")),
          content: extract_content_preview(markdown)
        )
      end
    end

    def parse_categories
      Llms::Generate.split_list(context.input.categories)
    end

    def parse_excludes
      Llms::Generate.split_list(context.input.excludes)
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
      return clean_fallback if clean_fallback.present? && clean_fallback.length > 20
      return "" if markdown.blank?

      lines = markdown.split("\n").map(&:strip)
      candidate = lines.find do |line|
        line.present? && !line.start_with?("#") && !line.start_with?("```") && !line.start_with?("-") && line.length > 30
      end

      candidate ? to_sentence(candidate)[0, 160] : ""
    end

    def extract_content_preview(markdown)
      return "" if markdown.blank?

      # Remove code blocks and links, keep meaningful text
      clean = markdown
        .gsub(/```[\s\S]*?```/, "")
        .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
        .gsub(/[#*_`]/, "")
        .split("\n")
        .map(&:strip)
        .reject { |line| line.blank? || line.length < 20 }
        .first(8)
        .join(" ")

      to_sentence(clean)[0, 800]
    end
  end
end
