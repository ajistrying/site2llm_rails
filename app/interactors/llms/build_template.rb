module Llms
  # Builds the final llms.txt template content
  #
  # Expected context:
  # - input: Llms::Generate::SurveyInput (required)
  # - pages: Array of Llms::Generate::PageItem (required)
  # - questions: String of questions (required)
  #
  # Sets in context:
  # - content: String containing the generated llms.txt
  #
  class BuildTemplate
    include Interactor

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

    def call
      title = ensure_sentence(context.input.site_name).presence || "Your Project"
      summary = ensure_sentence(context.summary || context.input.summary).presence || "A factual, one sentence description of who this site helps and what it provides."
      base_url = normalize_url(context.input.site_url)
      priority_urls = parse_url_list(context.input.priority_pages, base_url)
      priority_set = priority_urls.map { |u| normalize_for_match(u) }.to_set
      optional_urls = parse_url_list(context.input.optional_pages, base_url).reject { |u| priority_set.include?(normalize_for_match(u)) }
      optional_set = optional_urls.map { |u| normalize_for_match(u) }.to_set
      question_list = Llms::Generate.split_list(context.questions)
      pages_by_url = context.pages.index_by { |page| normalize_for_match(page.url) }

      # Build priority items with meaningful descriptions
      priority_items = priority_urls.filter_map do |url|
        existing = pages_by_url[normalize_for_match(url)]
        if existing && has_meaningful_description?(existing.description)
          existing
        elsif existing
          # Has page but no good description - create with contextual fallback
          Llms::Generate::PageItem.new(
            section: existing.section,
            title: existing.title,
            url: url,
            description: contextual_description(url, existing.title)
          )
        else
          # No page data at all - create minimal entry
          Llms::Generate::PageItem.new(
            section: nil,
            title: title_from_url(url),
            url: url,
            description: contextual_description(url, title_from_url(url))
          )
        end
      end

      # Build optional items similarly
      optional_items = optional_urls.filter_map do |url|
        existing = pages_by_url[normalize_for_match(url)]
        if existing && has_meaningful_description?(existing.description)
          existing
        elsif existing
          Llms::Generate::PageItem.new(
            section: existing.section,
            title: existing.title,
            url: url,
            description: contextual_description(url, existing.title)
          )
        else
          Llms::Generate::PageItem.new(
            section: nil,
            title: title_from_url(url),
            url: url,
            description: contextual_description(url, title_from_url(url))
          )
        end
      end

      lines = [ "# #{title}", "", "> #{summary}", "" ]

      if question_list.any?
        lines << "Key questions this site answers:"
        question_list.first(6).each do |question|
          clean = ensure_sentence(question)
          lines << "- #{clean.end_with?('?') ? clean : "#{clean}?"}"
        end
        lines << ""
      end

      # Group pages intelligently
      all_items = priority_items + context.pages.reject { |p| priority_set.include?(normalize_for_match(p.url)) || optional_set.include?(normalize_for_match(p.url)) }
      grouped = group_pages_by_topic(all_items.uniq { |p| normalize_for_match(p.url) })

      # Only render sections that have pages with meaningful descriptions
      grouped.each do |section, section_pages|
        valid_pages = section_pages.select { |p| has_meaningful_description?(p.description) }.first(6)
        next if valid_pages.empty?

        lines << "## #{section}"
        valid_pages.each do |page|
          lines << "- [#{page.title}](#{page.url}): #{page.description}"
        end
        lines << ""
      end

      # Optional section
      valid_optional = optional_items.select { |p| has_meaningful_description?(p.description) }.first(4)
      if valid_optional.any?
        lines << "## Optional"
        valid_optional.each do |page|
          lines << "- [#{page.title}](#{page.url}): #{page.description}"
        end
        lines << ""
      end

      context.content = lines.join("\n")
    end

    private

    # Section mappings based on common URL patterns
    SECTION_PATTERNS = {
      "Getting Started" => %w[getting-started quickstart start begin intro introduction setup install],
      "Documentation" => %w[docs documentation reference manual guide guides],
      "API" => %w[api apis endpoint endpoints developer developers],
      "Pricing" => %w[pricing price plans plan billing cost costs],
      "Products" => %w[product products features feature shop store collections],
      "Support" => %w[support help faq faqs contact us],
      "About" => %w[about company team who mission values],
      "Blog" => %w[blog news articles posts updates]
    }.freeze

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

    def parse_url_list(value, base_url)
      Llms::Generate.split_list(value)
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
      spaced.present? ? spaced.split.map(&:capitalize).join(" ") : parsed.host
    rescue URI::InvalidURIError
      value
    end

    def slugify(value)
      value.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end

    def has_meaningful_description?(description)
      return false if description.blank?
      return false if description.length < 20

      # Reject placeholder descriptions
      placeholder_phrases = [
        "user-prioritized page",
        "nice-to-have context",
        "summary not available",
        "see site for details"
      ]
      placeholder_phrases.none? { |phrase| description.downcase.include?(phrase) }
    end

    def contextual_description(url, title)
      # Generate a contextual description based on URL patterns
      path = URI.parse(url).path.downcase rescue ""

      case path
      when /pric/
        "View pricing plans and billing options."
      when /doc|guide|tutorial/
        "Read documentation and guides."
      when /api/
        "Explore API reference and endpoints."
      when /support|help|faq/
        "Get help and find answers to common questions."
      when /about|team|company/
        "Learn about the company and team."
      when /contact/
        "Get in touch and find contact information."
      when /blog|news/
        "Read latest news and articles."
      when /product|feature/
        "Explore product features and capabilities."
      when /collection|shop|store/
        "Browse products and collections."
      else
        "Learn more about #{title.downcase}."
      end
    end

    def group_pages_by_topic(pages)
      grouped = Hash.new { |h, k| h[k] = [] }

      pages.each do |page|
        section = infer_section(page)
        grouped[section] << page
      end

      # Sort sections by priority (most important first)
      section_priority = [ "Getting Started", "Products", "Pricing", "Documentation", "API", "Support", "About", "Blog", "Other" ]
      grouped.sort_by { |section, _| section_priority.index(section) || 99 }.to_h
    end

    def infer_section(page)
      # First check if page already has a section assigned
      return page.section if page.section.present?

      # Infer from URL patterns
      url_lower = page.url.downcase
      title_lower = page.title.to_s.downcase

      SECTION_PATTERNS.each do |section, patterns|
        return section if patterns.any? { |pattern| url_lower.include?(pattern) || title_lower.include?(pattern) }
      end

      "Other"
    end
  end
end
