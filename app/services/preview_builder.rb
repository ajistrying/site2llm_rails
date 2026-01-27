class PreviewBuilder
  MIN_LOCKED = 4

  def initialize(content)
    @content = content
  end

  def build
    lines = @content.split("\n")
    total = lines.length
    visible_count = (total / 2.0).ceil

    visible_count = [ 1, total - MIN_LOCKED ].max if total - visible_count < MIN_LOCKED

    visible = lines.first(visible_count).join("\n")
    locked_lines = lines.drop(visible_count)
    masked = locked_lines.map { |line| mask_line(line) }.join("\n")
    locked = masked.present? && visible.present? ? "\n#{masked}" : masked

    { visible: visible, locked: locked }
  end

  private

  def mask_line(line)
    line.gsub(/[^\s]/, "#")
  end
end
