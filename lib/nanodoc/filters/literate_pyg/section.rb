##
## Section
## =======
##

class Nanodoc::PygmentsLiterateFilter
  class Section

    def to_kramdown
      return if empty?

      html_id = "section_at_#{starts_at}"
      colspan = ( ' colspan="2"' unless code? )

      section_kd = <<EOF
<tr id=\"#{html_id}\"><td#{colspan} markdown=\"1\">
<div class=\"pilwrap\" markdown=\"0\"><a class=\"pilcrow\" href=\"##{html_id}\">#{starts_at}&nbsp;&#182;</a></div>

#{comment}

</td>
EOF

      section_kd << "<td class=\"code\"><pre>#{code}</pre></td>" if code?
      section_kd << "</tr>"
    end

    def comment_line(line_number, line_content)
      @comment_starts_at ||= line_number
      comment_lines << line_content
    end

    def code_line(line_number, line_content)
      @code_starts_at ||= line_number
      code_lines << line_content
    end

    attr_reader :comment_starts_at, :code_starts_at

    def starts_at
      [ comment_starts_at, code_starts_at ].compact.min
    end

    def discard_shebang!
      return unless comment?
      comment_lines.shift if comment_lines.first =~ /^\#\!/
      comment_lines.shift while comment_lines.first =~ /^\S*\s*-\*-.*-\*-\s*$/
      comment_lines.pop while comment_lines.last == ""
    end

    private

    def code
      @code ||= @code_lines.join("\n") if code?
    end

    def comment
      return unless comment?
      @comment ||= begin
                     comment_lines.pop while comment_lines.last =~ /^\s*$/
                     comment_lines.
                       map { |ln| ln.sub(/^\S+\s*/, '') }.
                       join("\n") if comment?
                   end
    end

    def code_lines
      @code_lines ||= []
    end

    def comment_lines
      @comment_lines ||= []
    end

    def code?
      @code_lines && !(@code_lines.empty?)
    end

    def comment?
      @comment_lines && !(@comment_lines.empty?)
    end

    def empty?
      !(code? || comment?)
    end
  end

  class SectionList < Array
    def to_kramdown
      return if empty?
      first.discard_shebang!

      rows = map(&:to_kramdown)
      rows.compact!
      return if rows.empty?

      <<EOF
<table class="table literate">
<tbody>
#{rows.join("\n")}
</tbody></table>
EOF
    end
  end
end
