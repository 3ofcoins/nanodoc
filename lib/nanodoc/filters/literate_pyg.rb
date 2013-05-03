require 'micromachine'
require 'nanoc'
require 'nanoc/filters/haml'
require 'nanoc/filters/maruku'
require 'nanoc/helpers/html_escape'

require 'nanodoc/pygments'
require 'nanodoc/site'

module Nanodoc
  class PygmentsLiterateFilter < Nanoc::Filters::Haml
    identifier :literate_pyg
    type :text

    include Nanoc::Helpers::HTMLEscape

    HAML_TEMPLATE = Nanodoc::Site::ROOT_DIR.join('layouts', 'literate_pyg.haml').read()

    def create_line_machine
      assigns[:sections] = []

      machine = MicroMachine.new(:bof)

      machine.transitions_for[:code]               = Hash.new(:code)
      machine.transitions_for[:code][:bof]         = :new_code
      machine.transitions_for[:code][:section]     = :new_code
      machine.transitions_for[:code][:new_section] = :new_code

      machine.when :indented_comment,
                   :bof =>           :new_side_note,
                   :code =>          :new_side_note,
                   :section =>       :new_side_note,
                   :new_section =>   :new_side_note,
                   :new_side_note => :side_note,
                   :side_note =>     :side_note

      machine.when :unindented_comment,
                   :bof =>           :new_section,
                   :code =>          :new_section,
                   :side_note =>     :new_section,
                   :new_side_note => :new_section,
                   :new_section =>   :section,
                   :section =>       :section

      machine.when :empty_line,
                   :new_section =>   :section,
                   :section =>       :section,
                   :new_side_node => :side_note,
                   :side_note =>     :side_note,
                   :new_code =>      :code,
                   :code =>          :code


      machine.on(:new_code) do
        assigns[:sections] << { :at => @ln, :code_lines => [render_code(@indent, @line)] }
      end

      machine.on(:new_section) do
        assigns[:sections] << { :at => @ln, :comment_lines => [@line.map(&:first).join] }
      end

      machine.on(:new_side_note) do
        assigns[:sections] << { :at => @ln, :comment_lines => [@line.map(&:first).join], :code_lines => [] }
      end

      machine.on(:code) do
        assigns[:sections].last[:code_lines] << [render_code(@indent, @line)]
      end

      machine.on(:section) do
        assigns[:sections].last[:comment_lines] << @line.map(&:first).join
      end

      machine.on(:side_note) do
        assigns[:sections].last[:comment_lines] << @line.map(&:first).join
      end

      machine
    end

    def render_code(indent, line)
      rv = indent.dup
      line.each do |text, css_class|
        if css_class
          rv << "<span class=\"#{css_class}\">#{h(text)}</span>"
        else
          rv << h(text)
        end
      end
      rv
    end


    def create_token_machine
      @ln = 1
      @indent = ''
      @line = []
      @is_code = false

      machine = MicroMachine.new(:bol)
      machine.transitions_for[:newline] = Hash.new(:bol)
      machine.transitions_for[:code]    = Hash.new(:code)
      machine.transitions_for[:comment] = Hash.new(:comment)
      machine.when :whitespace, :bol => :indent,
                                :indent => :indent,
                                :code => :code,
                                :comment => :comment
      machine.transitions_for[:eof] = Hash.new(:bol)
      machine.transitions_for[:eof][:bol] = :eof

      machine.on(:bol) do
        event = case
                when @is_code then      :code
                when @line == []   then :empty_line
                when @indent == '' then :unindented_comment
                else                    :indented_comment
                end
        line_machine.trigger(event)
        @indent = ''
        @line = []
        @is_code = false
        @ln += 1
      end

      machine.on(:indent) do
        @indent << @text
      end

      machine.on(:code) do
        @line << [@text, @css_class]
        @is_code = true
      end

      machine.on(:comment) do
        @line << [@text, @css_class]
      end

      machine
    end

    def run(content, params={})
      pyg.parsed.each do |text, type, css_class|
        @text = text
        @css_class = css_class
        event = case type
                when 'Text.Newline'    then :newline
                when 'Text.Whitespace' then :whitespace
                when /^Comment/        then :comment
                else                        :code
                end
        token_machine.trigger(event)
      end
      token_machine.trigger(:eof)

      if assigns[:sections]
        if opening_comments = assigns[:sections].first[:comment_lines]
          opening_comments.shift if opening_comments.first =~ /^\#\!/
          opening_comments.shift while opening_comments.first =~ /^\S*\s*-\*-.*-\*-\s*$/
          opening_comments.pop while opening_comments.last == ""
          assigns[:sections].shift if opening_comments.empty? && !assigns[:sections].first[:code_lines]
        end

        assigns[:sections].each do |section|
          if section[:code_lines]
            section[:code] = "<pre>#{section[:code_lines].join("\n")}</pre>"
          end
          if section[:comment_lines]
            section[:comment_lines].pop while section[:comment_lines].last == ""
            comment_md = section[:comment_lines].
              map { |ln| ln.sub(/^\S*\s*/, '') }.
              join("\n")
            section[:comment] =
              Nanoc::Filters::Kramdown.new.setup_and_run(comment_md)
          end
        end

        super(HAML_TEMPLATE, params)
      else
        "<pre>#{h(content)}</pre>"
      end
    end

    def pyg
      @pyg ||= Nanodoc::Pygments.new(@item)
    end

    def token_machine
      @token_machine ||= create_token_machine
    end

    def line_machine
      @machine ||= create_line_machine
    end
  end
end
