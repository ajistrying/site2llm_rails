module Llms
  # Orchestrates the full llms.txt generation workflow
  #
  # Simplified Usage (v2):
  #   result = Llms::Generate.call(
  #     site_name: "Acme Corp",
  #     site_url: "https://acme.com",
  #     summary: "Acme provides inventory sync for e-commerce businesses.",
  #     important_pages: "/pricing, /docs, /features, /about"
  #   )
  #
  #   if result.success?
  #     result.content    # => Generated llms.txt content
  #     result.mode       # => "live"
  #   else
  #     result.error      # => Error message
  #   end
  #
  class Generate
    include Interactor::Organizer

    PRICE_USD = 8

    SITE_TYPES = %w[docs marketing saas ecommerce marketplace services education media].freeze

    SurveyInput = Struct.new(
      :site_name, :site_url, :summary, :categories, :site_type,
      :excludes, :priority_pages, :optional_pages, :questions,
      keyword_init: true
    )

    PageItem = Struct.new(:section, :title, :url, :description, :content, keyword_init: true)

    class CrawlUnavailableError < StandardError; end

    organize Llms::Crawl, Llms::Enrich, Llms::BuildTemplate, Llms::ValidateOutput

    before do
      context.input = normalize_input(context.to_h)
    end

    after do
      context.mode = "live"
    end

    class << self
      def validate(params)
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

        errors[:summary] = "Describe what your business does (20+ characters)." if input[:summary].to_s.strip.length < 20

        # Simplified: now we just need important_pages (maps to priority_pages)
        important_count = split_list(input[:priority_pages]).length
        errors[:important_pages] = "Add 3-8 important page URLs." unless important_count.between?(3, 8)

        errors
      end

      def normalize_params(params)
        # Handle both old format (priority_pages) and new format (important_pages)
        priority = params[:important_pages].presence || params[:priority_pages]

        {
          site_name: params[:site_name].to_s.strip,
          site_url: normalize_site_url(params[:site_url].to_s),
          summary: params[:summary].to_s.strip,
          categories: params[:categories].to_s.strip,
          site_type: infer_site_type(params),
          excludes: params[:excludes].to_s.strip,
          priority_pages: priority.to_s.strip,
          optional_pages: params[:optional_pages].to_s.strip,
          questions: params[:questions].to_s.strip
        }
      end

      def normalize_site_url(value)
        trimmed = value.to_s.strip
        return "" if trimmed.blank?
        return trimmed if trimmed.match?(/\Ahttps?:\/\//i)
        return "https://#{trimmed}" if trimmed.match?(/\A[\w.-]+\.\w{2,}(\/.*)?/)
        trimmed
      end

      def split_list(value)
        return [] if value.blank?
        value.split(/[\n,]+/).map(&:strip).reject { |item| item.blank? || none_value?(item) }
      end

      def none_value?(value)
        %w[none n/a na].include?(value.downcase.strip)
      end

      def infer_site_type(params)
        # Use explicit site_type if provided
        explicit = params[:site_type].to_s.strip
        return explicit if explicit.present? && SITE_TYPES.include?(explicit)

        # Otherwise infer from URL and summary
        url = params[:site_url].to_s.downcase
        summary = params[:summary].to_s.downcase

        return "docs" if url.include?("docs.") || summary.include?("documentation")
        return "ecommerce" if %w[shop store cart checkout product].any? { |w| url.include?(w) || summary.include?(w) }
        return "saas" if %w[saas software platform app dashboard].any? { |w| summary.include?(w) }
        return "services" if %w[agency consulting service].any? { |w| summary.include?(w) }
        return "education" if %w[learn course training academy].any? { |w| url.include?(w) || summary.include?(w) }
        return "media" if %w[blog news magazine].any? { |w| url.include?(w) }

        "marketing" # Default fallback
      end
    end

    private

    def normalize_input(params)
      normalized = self.class.normalize_params(params)
      SurveyInput.new(**normalized)
    end
  end
end
