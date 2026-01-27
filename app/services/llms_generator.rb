class LlmsGenerator
  PRICE_USD = 8

  SITE_TYPES = %w[docs marketing saas ecommerce marketplace services education media].freeze

  SurveyInput = Struct.new(
    :site_name, :site_url, :summary, :categories, :site_type,
    :excludes, :priority_pages, :optional_pages, :questions,
    keyword_init: true
  )

  PageItem = Struct.new(:section, :title, :url, :description, keyword_init: true)

  class CrawlUnavailableError < StandardError; end

  def initialize(input)
    @input = normalize_input(input)
  end

  def generate
    pages = crawl_pages
    enrichment = enrich_pages_and_questions(pages)
    content = build_template(enrichment[:pages], enrichment[:questions])

    { content: content, mode: "live" }
  end

  def self.validate(params)
    errors = {}
    input = normalize_params(params)

    errors[:site_name] = "Enter a project or brand name." if input[:site_name].blank?

    url = input[:site_url].to_s.strip
    if url.blank?
      errors[:site_url] = "Enter your homepage URL."
    else
      begin
        parsed = URI.parse(url)
        errors[:site_url] = "Use an http or https URL." unless %w[http https].include?(parsed.scheme)
      rescue URI::InvalidURIError
        errors[:site_url] = "Enter a valid URL starting with http or https."
      end
    end

    errors[:summary] = "Provide a short, factual sentence (20+ characters)." if input[:summary].to_s.strip.length < 20

    categories = split_list(input[:categories])
    errors[:categories] = "Add at least one section." if categories.empty?

    priority_count = split_list(input[:priority_pages]).length
    errors[:priority_pages] = "Add 3-8 priority URLs." unless priority_count.between?(3, 8)

    questions = split_list(input[:questions])
    errors[:questions] = "Add at least one question." if questions.empty?

    errors
  end

  def self.normalize_params(params)
    {
      site_name: params[:site_name].to_s.strip,
      site_url: normalize_site_url(params[:site_url].to_s),
      summary: params[:summary].to_s.strip,
      categories: params[:categories].to_s.strip,
      site_type: params[:site_type].to_s.strip.presence || "docs",
      excludes: params[:excludes].to_s.strip,
      priority_pages: params[:priority_pages].to_s.strip,
      optional_pages: params[:optional_pages].to_s.strip,
      questions: params[:questions].to_s.strip
    }
  end

  def self.normalize_site_url(value)
    trimmed = value.to_s.strip
    return "" if trimmed.blank?
    return trimmed if trimmed.match?(/\Ahttps?:\/\//i)
    return "https://#{trimmed}" if trimmed.match?(/\A[\w.-]+\.\w{2,}(\/.*)?/)
    trimmed
  end

  def self.split_list(value)
    return [] if value.blank?
    value.split(/[\n,]+/).map(&:strip).reject { |item| item.blank? || none_value?(item) }
  end

  def self.none_value?(value)
    %w[none n/a na].include?(value.downcase.strip)
  end

  private

  def normalize_input(params)
    normalized = self.class.normalize_params(params)
    SurveyInput.new(**normalized)
  end

  def crawl_pages
    FirecrawlService.new(@input).crawl
  end

  def enrich_pages_and_questions(pages)
    LlmEnrichService.new(@input, pages).enrich
  end

  def build_template(pages, questions)
    TemplateBuilder.new(@input, pages, questions).build
  end
end
