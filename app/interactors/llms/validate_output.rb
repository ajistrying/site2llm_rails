module Llms
  # Validates the generated llms.txt content meets quality standards
  #
  # Expected context:
  # - content: String containing the generated llms.txt (required)
  #
  # Sets in context:
  # - content: Potentially cleaned/improved content
  # - validation_warnings: Array of warnings (if any)
  #
  class ValidateOutput
    include Interactor

    MIN_SUMMARY_LENGTH = 30
    MIN_PAGES_WITH_DESCRIPTIONS = 3
    MIN_QUESTIONS = 2

    def call
      context.validation_warnings = []
      content = context.content.to_s

      validate_structure(content)
      validate_summary(content)
      validate_pages(content)
      validate_questions(content)

      # Clean up any remaining empty sections
      context.content = remove_empty_sections(content)
    end

    private

    def validate_structure(content)
      unless content.start_with?("# ")
        context.validation_warnings << "Missing H1 title"
      end

      unless content.include?("> ")
        context.validation_warnings << "Missing summary blockquote"
      end
    end

    def validate_summary(content)
      match = content.match(/^> (.+)$/m)
      return unless match

      summary = match[1].strip
      if summary.length < MIN_SUMMARY_LENGTH
        context.validation_warnings << "Summary too short (#{summary.length} chars, need #{MIN_SUMMARY_LENGTH}+)"
      end

      # Check for generic marketing phrases
      marketing_phrases = [ "leading provider", "best-in-class", "world-class", "innovative solution", "comprehensive platform" ]
      marketing_phrases.each do |phrase|
        if summary.downcase.include?(phrase)
          context.validation_warnings << "Summary contains marketing phrase: '#{phrase}'"
        end
      end
    end

    def validate_pages(content)
      # Count pages with meaningful descriptions
      page_lines = content.scan(/^- \[.+\]\(.+\): .+$/)
      meaningful_pages = page_lines.count do |line|
        description = line.split("): ", 2).last.to_s
        description.length >= 20 && !placeholder_description?(description)
      end

      if meaningful_pages < MIN_PAGES_WITH_DESCRIPTIONS
        context.validation_warnings << "Only #{meaningful_pages} pages with meaningful descriptions (need #{MIN_PAGES_WITH_DESCRIPTIONS}+)"
      end
    end

    def validate_questions(content)
      question_section = content.match(/Key questions this site answers:\n((?:- .+\n?)+)/m)
      return unless question_section

      questions = question_section[1].scan(/^- .+$/)
      if questions.length < MIN_QUESTIONS
        context.validation_warnings << "Only #{questions.length} questions (need #{MIN_QUESTIONS}+)"
      end
    end

    def placeholder_description?(description)
      placeholders = [
        "user-prioritized",
        "nice-to-have",
        "summary not available",
        "see site for details",
        "learn more about"
      ]
      placeholders.any? { |p| description.downcase.include?(p) }
    end

    def remove_empty_sections(content)
      lines = content.split("\n")
      result = []
      skip_until_next_section = false

      lines.each_with_index do |line, index|
        if line.start_with?("## ")
          # Check if next non-empty line is another section or end of content
          next_content_line = lines[(index + 1)..].find { |l| l.strip.present? }
          if next_content_line.nil? || next_content_line.start_with?("## ")
            skip_until_next_section = true
            next
          else
            skip_until_next_section = false
          end
        end

        result << line unless skip_until_next_section && !line.start_with?("## ")

        # Reset skip flag when we hit a new section
        skip_until_next_section = false if line.start_with?("## ")
      end

      # Clean up multiple consecutive blank lines
      result.join("\n").gsub(/\n{3,}/, "\n\n")
    end
  end
end
