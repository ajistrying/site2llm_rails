class TemplateBuilder
  SITE_TYPE_EXAMPLES = {
    "docs" => [
      { suffix: "getting-started", title: "Getting started", description: "Install, configure, and ship your first project." },
      { suffix: "guides", title: "Guides", description: "Step-by-step workflows and best practices." },
      { suffix: "api", title: "API reference", description: "Endpoints, parameters, and response shapes." }
    ],
    "marketing" => [
      { suffix: "features", title: "Product capabilities", description: "What the product does and how it works." },
      { suffix: "pricing", title: "Pricing", description: "Plans, limits, and billing details." },
      { suffix: "case-studies", title: "Case studies", description: "Real outcomes and customer proof." }
    ],
    "saas" => [
      { suffix: "product", title: "Product overview", description: "Core capabilities and workflows." },
      { suffix: "pricing", title: "Pricing", description: "Plans, limits, and billing details." },
      { suffix: "security", title: "Security", description: "Compliance, data handling, and trust." }
    ],
    "ecommerce" => [
      { suffix: "collections", title: "Collections", description: "Top categories and product groups." },
      { suffix: "shipping-returns", title: "Shipping & returns", description: "Delivery times, costs, and policies." },
      { suffix: "support", title: "Customer support", description: "Help center and contact options." }
    ],
    "marketplace" => [
      { suffix: "browse", title: "Browse listings", description: "How buyers discover offerings." },
      { suffix: "seller-guidelines", title: "Seller guidelines", description: "Requirements and onboarding rules." },
      { suffix: "fees", title: "Fees", description: "Marketplace pricing and payouts." }
    ],
    "services" => [
      { suffix: "services", title: "Service menu", description: "What you offer and scope." },
      { suffix: "pricing", title: "Pricing", description: "Packages and estimates." },
      { suffix: "contact", title: "Contact", description: "How to book or request a quote." }
    ],
    "education" => [
      { suffix: "programs", title: "Programs", description: "Courses, tracks, and outcomes." },
      { suffix: "admissions", title: "Admissions", description: "Requirements, deadlines, and steps." },
      { suffix: "tuition", title: "Tuition & aid", description: "Costs, scholarships, and payment options." }
    ],
    "media" => [
      { suffix: "news", title: "Newsroom", description: "Latest announcements and updates." },
      { suffix: "press", title: "Press kit", description: "Brand assets and media contacts." },
      { suffix: "newsletter", title: "Newsletter", description: "Subscribe and past issues." }
    ]
  }.freeze

  FALLBACK_SECTIONS = [ "Core documentation", "API reference", "Guides" ].freeze

  def initialize(input, pages, questions)
    @input = input
    @pages = pages
    @questions = questions
  end

  def build
    title = ensure_sentence(@input.site_name).presence || "Your Project"
    line = ensure_sentence(@input.summary).presence || "A factual, one sentence description of who this site helps and what it provides."
    base_url = normalize_url(@input.site_url)
    section_list = parse_categories
    sections = section_list.any? ? section_list : FALLBACK_SECTIONS
    priority_urls = parse_url_list(@input.priority_pages, base_url)
    priority_set = priority_urls.map { |u| normalize_for_match(u) }.to_set
    optional_urls = parse_url_list(@input.optional_pages, base_url).reject { |u| priority_set.include?(normalize_for_match(u)) }
    optional_set = optional_urls.map { |u| normalize_for_match(u) }.to_set
    question_list = LlmsGenerator.split_list(@questions)
    pages_by_url = @pages.index_by { |page| normalize_for_match(page.url) }

    priority_items = priority_urls.map do |url|
      pages_by_url[normalize_for_match(url)] || LlmsGenerator::PageItem.new(
        section: guess_section_from_url(url, sections),
        title: title_from_url(url),
        url: url,
        description: "User-prioritized page for AI answers."
      )
    end

    optional_items = optional_urls.map do |url|
      pages_by_url[normalize_for_match(url)] || LlmsGenerator::PageItem.new(
        section: guess_section_from_url(url, sections),
        title: title_from_url(url),
        url: url,
        description: "Nice-to-have context that can be skipped."
      )
    end

    lines = [ "# #{title}", "", "> #{line}", "" ]

    if question_list.any?
      lines << "Key questions this site should answer:"
      question_list.first(6).each do |question|
        clean = ensure_sentence(question)
        lines << "- #{clean.end_with?('?') ? clean : "#{clean}?"}"
      end
      lines << ""
    end

    if @pages.any? || priority_items.any?
      grouped = map_pages_to_sections(@pages + priority_items, sections)
      sections.each do |section|
        lines << "## #{section}"
        section_pages = grouped[section] || []
        section_pages_by_url = section_pages.index_by { |page| normalize_for_match(page.url) }
        priority_for_section = priority_urls.filter_map { |url| section_pages_by_url[normalize_for_match(url)] }
        normal_pages = section_pages.reject do |page|
          key = normalize_for_match(page.url)
          priority_set.include?(key) || optional_set.include?(key)
        end
        ordered_pages = (priority_for_section + normal_pages).first(6)
        ordered_pages.each do |page|
          lines << "- [#{page.title}](#{page.url}): #{page.description}"
        end
        lines << ""
      end
    else
      sections.each_with_index do |section, index|
        section_slug = slugify(section)
        examples = select_examples(index)
        lines << "## #{section}"
        examples.each do |example|
          url = join_url(base_url, section_slug, example[:suffix])
          lines << "- [#{example[:title]}](#{url}): #{example[:description]}"
        end
        lines << ""
      end
    end

    if optional_items.any?
      lines << "## Optional"
      optional_items.first(6).each do |page|
        lines << "- [#{page.title}](#{page.url}): #{page.description}"
      end
      lines << ""
    end

    lines.join("\n")
  end

  private

  def ensure_sentence(value)
    value.to_s.gsub(/\s+/, " ").strip
  end

  def normalize_url(value)
    trimmed = value.to_s.strip
    return "https://example.com" if trimmed.blank?
    trimmed.gsub(/\/+\z/, "")
  end

  def normalize_for_match(value)
    value.gsub(/\/+\z/, "").downcase
  end

  def parse_categories
    LlmsGenerator.split_list(@input.categories)
  end

  def parse_url_list(value, base_url)
    LlmsGenerator.split_list(value)
      .filter_map { |entry| resolve_url(base_url, entry) }
      .uniq { |url| normalize_for_match(url) }
  end

  def resolve_url(base_url, value)
    trimmed = value.to_s.strip
    return nil if trimmed.blank?
    base = base_url.end_with?("/") ? base_url : "#{base_url}/"
    URI.join(base, trimmed).to_s.gsub(/\/+\z/, "")
  rescue URI::InvalidURIError
    trimmed
  end

  def title_from_url(value)
    parsed = URI.parse(value)
    path = parsed.path.gsub(/\/+\z/, "")
    segment = path.split("/").reject(&:blank?).last
    return parsed.host if segment.blank?
    decoded = CGI.unescape(segment)
    spaced = decoded.gsub(/[-_]+/, " ")
    spaced.present? ? spaced.capitalize : parsed.host
  rescue URI::InvalidURIError
    value
  end

  def guess_section_from_url(url, sections)
    match = sections.find { |section| url.downcase.include?(slugify(section)) }
    match || sections.first || "Core documentation"
  end

  def slugify(value)
    value.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
  end

  def join_url(base, *parts)
    cleaned = [ base.gsub(/\/+\z/, "") ] + parts.map { |p| p.gsub(/\A\/+|\/+\z/, "") }
    cleaned.reject(&:blank?).join("/")
  end

  def map_pages_to_sections(pages, sections)
    grouped = sections.index_with { [] }

    pages.each do |page|
      matched = sections.find { |section| page.section == section } ||
                sections.find { |section| page.url.include?(slugify(section)) } ||
                sections.first
      grouped[matched] << page if matched
    end

    grouped
  end

  def select_examples(index)
    options = SITE_TYPE_EXAMPLES[@input.site_type] || SITE_TYPE_EXAMPLES["marketing"]
    [ options[index % options.length], options[(index + 1) % options.length] ]
  end
end
