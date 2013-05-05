require 'micromachine'
require 'nanoc'
require 'nanoc/filters/haml'
require 'nanoc/filters/maruku'
require 'nanoc/helpers/html_escape'

require 'nanodoc/pygments'
require 'nanodoc/site'

##
## Nanodoc::PygmentsLiterateFilter
## ===============================
##
## Parses text with [Pygments](http://pygments.org), splits comments
## from code, and renders it in a literate programming layout.
##
## A state machine is used to separate comment sections from code.
##

class Nanodoc::PygmentsLiterateFilter < Nanoc::Filters::Haml
  identifier :literate_pyg
  type :text

  requires 'haml'
  include Nanoc::Helpers::HTMLEscape

##
## Top level methods
## -----------------
##

  # Full path to the literate programming template
  HAML_TEMPLATE = Nanodoc::Site::ROOT_DIR.join('layouts', 'literate_pyg.haml').read()

  #
  # ### Main entry point
  def run(content, params={})
    handle_parsed_file(pyg.parsed)

    if assigns[:sections]
      process_sections
      super(HAML_TEMPLATE, params)
    else
      "<pre>#{h(content)}</pre>"
    end
  end

  # Returns [`Nanodoc::Pygments`](../pygments.rb) instance for current file
  def pyg
    @pyg ||= Nanodoc::Pygments.new(@item)
  end

  #
  # ### Feed tokens to the state machine
  def handle_parsed_file(tokens)
    # Feed BOF to make sure everything is initialized.
    #
    # *[BOF]: Beginning Of File
    feed_bof

    # Leave token's text and CSS class in instance variables, and
    # leave rest of work to the token state machine.
    tokens.each do |text, type, css_class|
      feed_token(text, type, css_class)
    end

    # Feed EOF to finalize all that needs finalizing.
    #
    # *[EOF]: End Of File
    feed_eof
  end

  #
  # ### Process sections for templates
  def process_sections
    # Strip shebang and mode lines at beginning of file. If initial
    # comment section consisted only of these, discard the whole
    # section.
    if opening_comments = assigns[:sections].first[:comment_lines]
      opening_comments.shift if opening_comments.first =~ /^\#\!/
      opening_comments.shift while opening_comments.first =~ /^\S*\s*-\*-.*-\*-\s*$/
      opening_comments.pop while opening_comments.last == ""
      assigns[:sections].shift if opening_comments.empty? && !assigns[:sections].first[:code_lines]
    end

    assigns[:sections].each do |section|
      # Merge code lines into a `<pre>` tag.
      if section[:code_lines] && !(section[:code_lines].empty?)
        section[:code] = "<pre>#{section[:code_lines].join("\n")}</pre>"
      end
      # Discard empty comment lines at the end; render Kramdown if
      # anything's left.
      if section[:comment_lines]
        section[:comment_lines].pop while section[:comment_lines].last =~ /^\s*$/

        unless section[:comment_lines].empty?
          # Strip comment prefix and whitespace. FIXME: be smarter.
          comment_md = section[:comment_lines].
            map { |ln| ln.sub(/^\S+\s*/, '') }.
            join("\n")

          section[:comment] =
            Nanoc::Filters::Kramdown.new.setup_and_run(comment_md)
        end
      end
    end
  end

##
## The Token State Machine
## -----------------------
##
## The event handlers use following instance attributes to handle state:
##
## @token
## : Input: `[text, css_class]` --- Text of the current token, and the
##   CSS class from Pygments to highlight syntax
##
## @ln
## : Line number
##
## @indent
## : String of whitespace at BOL. Discarded for comments, kept for
##   code to keep indentation.
##
## @is_code
## : Set at BOL to `false`, updated to `true` as soon as non-comment
##   and non-whitespace token is seen. Used to distinguish comment
##
## @line_tokens
## : Array of tokens seen since BOL (without `@indent`)
##   lines from code lines.
##
## @line
## : Output: a string with either cleaned raw comment text (excluding
##   indentation, including comment syntax), or HTML-formatted
##   highlighted code line including indentation, depending on
##   `@is_code`.
##
## *[BOL]: Beginning Of Line

  # "Feed BOF" to the state machine, i.e. initialize it.
  #
  # *[BOF]: Beginning Of File
  def feed_bof
    reset_line(1)
  end

  # Feed one token to the state machine.
  def feed_token(text, type, css_class)
    @token = [ text, css_class ]
    token_machine.trigger case type
                          when 'Text.Newline'    then :newline
                          when 'Text.Whitespace' then :whitespace
                          when /^Comment/        then :comment
                          else                        :code
                          end
  end

  # Feed EOF to the state machine.
  #
  # Makes sure the machine properly handled last line if the file
  # didn't end with a newline by triggering a `:newline` event if
  # machine isn't at BOL.
  #
  # *[EOF]: End Of File
  # *[BOL]: Beginning Of Line
  def feed_eof
    token_machine.trigger :newline unless token_machine.state == :bol
  end

  # Reset instance attributes for new line of input.
  #
  # If `ln` is provided, sets `@ln` to this value; otherwise, increases `@ln`.
  def reset_line(ln=nil)
    @ln = ln || (@ln||-1)+1
    @indent = ''
    @line_tokens = []
    @is_code = false
  end

  # Accessor that takes care of creating the token state machine
  def token_machine
    @token_machine ||= create_token_machine
  end

  #
  # ### Definition of the token state machine
  #
  # **States:**
  #
  # :bol
  # : Beginning Of Line (BOL)
  #
  # :indent
  # : Sequence of whitespace at BOL
  #
  # :code
  # : Sequence of non-comment tokens
  #
  # :coment
  # : Sequence of comment tokens
  #
  def create_token_machine
    # Machine starts at BOL
    #
    # *[BOL]: Beginning Of Line
    machine = MicroMachine.new(:bol)

    # Some tokens always transition to the same state
    machine.transitions_for[:newline] = Hash.new(:bol)
    machine.transitions_for[:code]    = Hash.new(:code)
    machine.transitions_for[:comment] = Hash.new(:comment)

    # Whitespace at BOL or after indent is indent.
    # Otherwise it stays in current state.
    machine.when :whitespace,
                 :bol => :indent,
                 :indent => :indent,
                 :code => :code,
                 :comment => :comment

    machine.on(:any) { handle_transition(machine.state) }

    machine
  end

  # Handle token state transitions
  def handle_transition(state)
    case state

    ## Transition into BOL is a newline. We render the line from
    ## tokens, check its kind, and trigger event on the line state
    ## machine. After the line is handled, we reset state and increase
    ## the line number.
    when :bol
      line_machine.trigger case
                           when @line_tokens == []
                             @line = ''
                             :empty_line
                           when @is_code
                             render_code_line
                             :code
                           else # comment line
                             render_comment_line
                             if @line =~ /^\S*\s*$/
                               :empty_comment
                             else
                               :comment
                             end
                           end
      reset_line

    ## Append whitespace to current line's indentation.
    when :indent
      @indent << @token.first

    ## Note that we're looking at the code line, and append the
    ## current token to the list.
    when :code
      @line_tokens << @token
      @is_code = true

    ## Append full token to the list, as we can't be sure before EOL
    ## that this line doesn't contain code.
    ##
    ## *[EOL]: End Of Line
    when :comment
      @line_tokens << @token
    end
  end

  # Render a line of code to HTML, using CSS classes from Pygments.
  def render_code_line
    @line = @indent << @line_tokens.map! do |text, css_class|
      if css_class
        "<span class=\"#{css_class}\">#{h(text)}</span>"
      else
        h(text)
      end
    end.join
  end

  # Render a comment line by joining line tokens' texts and stripping
  # initial non-whitespace character sequence.
  def render_comment_line
    @line = @line_tokens.map!(&:first).join
  end

  ##
  ## The Line State Machine
  ## ----------------------
  ##
  ## The event handlers take `@text` to get current line's text, and
  ## leave their output in the `assigns[:sections]` global.

  # Accessor that takes care of creating the line state machine
  def line_machine
    @line_machine ||= create_line_machine
  end

  #
  # ### Definition of the line state machine
  #
  # **States:**
  #
  # :bof
  # : Beginning Of File (BOF)
  #
  # :new_code
  # : Beginning of a code section (code line following BOF or a wide note)
  #
  # :new_wide_note
  # : Beginning of a wide note section (empty comment line following BOF or a code line)
  #
  # :new_side_note
  # : Beginning of a side note section (non-empty comment following BOF or a code line)
  #
  # :code
  # : Code continuing a code section or a side note section
  #
  # :wide_note
  # : Comment continuing a wide note section
  #
  # :side_note
  # : Comment continuing a side note section
  #
  # *[BOF]: Beginning Of File
  def create_line_machine
    # Machine starts at BOF
    machine = MicroMachine.new(:bof)

    # Code at BOF or after wide note starts a new code section.
    #
    # A `:new_wide_note` state receiving `:code` means that code
    # directly follows an empty comment, which have meant beginning of
    # a code section rather than a wide note section.
    machine.transitions_for[:code]             = Hash.new(:code)
    machine.transitions_for[:code][:bof]       = :new_code
    machine.transitions_for[:code][:wide_note] = :new_code

    # Empty comment at BOF or after code means new wide note (or new
    # code section, depending on what follows).  A sequence of empty
    # comments stays in `:new_wide_note`.  Empty comment inside a
    # section's comment block continues the comment block.
    machine.when :empty_comment,
                 :bof =>           :new_wide_note,
                 :code =>          :new_wide_note,
                 :new_wide_note => :new_wide_note,
                 :new_side_note => :side_note,
                 :wide_note =>     :wide_note,
                 :side_note =>     :side_note

    # Non-empty comment at BOF or after code starts a new side note
    # section. Inside a note section's comment block, it continues the
    # section.
    machine.when :comment,
                 :bof =>           :new_side_note,
                 :code =>          :new_side_note,
                 :new_wide_note => :wide_note,
                 :new_side_note => :side_note,
                 :wide_note =>     :wide_note,
                 :side_note =>     :side_note

    # Empty line usually continues current state. If an empty line (as
    # opposed to empty comment) follows a wide note's comment block,
    # this ends the note. This way, it is possible to write multiple
    # consecutive wide note sections.
    machine.when :empty_line,
                 :code =>          :code,
                 :new_code =>      :code,
                 :new_wide_note => :new_wide_note,
                 :new_side_node => :side_note,
                 :wide_note =>     :bof,
                 :side_note =>     :side_note

    # Entering a `:new_*something*` state starts a new section. If the
    # event line has code or comment, we add it. Continuation of a
    # code or comment block appends to current section.
    machine.on(:new_wide_note) { add_section }
    machine.on(:new_code)      { add_section ; add_code }
    machine.on(:new_side_note) { add_section ; add_comment }
    machine.on(:code)          { add_code }
    machine.on(:wide_note)     { add_comment }
    machine.on(:side_note)     { add_comment }

    machine
  end

  # Start a new section
  def add_section(args={})
    (assigns[:sections] ||= []) << { :at => @ln }.merge!(args)
  end

  # Adds comment line to the current section
  def add_comment
    (current_section[:comment_lines] ||= []) << @line
  end

  # Adds code line to the current section
  def add_code
    (current_section[:code_lines] ||= []) << @line
  end

  # Accessor for current section
  def current_section
    assigns[:sections].last
  end
end
