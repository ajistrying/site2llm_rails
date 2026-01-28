module Llms
  # Builds a preview of llms.txt content with locked/masked portion
  #
  # Usage:
  #   result = Llms::BuildPreview.call(content: "# My Site\n...")
  #
  #   if result.success?
  #     result.visible  # => Visible preview portion
  #     result.locked   # => Masked/locked portion
  #   end
  #
  class BuildPreview
    include Interactor

    MIN_LOCKED = 4

    def call
      context.fail!(error: "Content is required") if context.content.blank?

      lines = context.content.split("\n")
      total = lines.length
      visible_count = (total / 2.0).ceil

      visible_count = [ 1, total - MIN_LOCKED ].max if total - visible_count < MIN_LOCKED

      context.visible = lines.first(visible_count).join("\n")
      locked_lines = lines.drop(visible_count)
      masked = locked_lines.map { |line| mask_line(line) }.join("\n")
      context.locked = masked.present? && context.visible.present? ? "\n#{masked}" : masked
    end

    private

    def mask_line(line)
      line.gsub(/[^\s]/, "#")
    end
  end
end
