require 'pathname'

require 'multi_json'
require 'nanoc'

module Nanodoc
  class Pygments < ::Nanoc::Store
    PYGMENTS2JSON = Pathname.new(__FILE__).dirname.join('pygments2json.py')

    # initialize(item)
    # ----------------
    # `item` can be a `Nanoc::Item`, a `Pathname`, or a string with
    # path to file.
    def initialize(item)
      item = Pathname.new(item) if item.is_a?(String)
      if item.is_a?(Pathname)
        item = item.realpath
        item = Nanoc::Item.new(
          item.read, {:filename => item.to_s }, "#{item}/",
          :binary => false, :mtime => item.stat.mtime)
      end

      @item = item
      @parsed = nil

      super("tmp/pygments#{item.identifier}parsed", 1)
    end

    # parsed()
    # --------
    # Returns an array parsed by Pygments. Each of the elements is an
    # array of form: `[ string, token_type, css_class ]` (`css_class`
    # may be omitted; in this case, text shouldn't be formatted with
    # any class).
    def parsed
      load
      unless @parsed
        @parsed = MultiJson.load(`pygmentize -f tokens #{@item[:filename]} | #{PYGMENTS2JSON}`).map(&:compact)
        store
      end
      @parsed
    end

    protected

    def data
      [ @item.mtime, parsed ]
    end

    def data=(new_data)
      mtime, parsed = new_data
      @parsed = parsed if mtime == @item.mtime
    end
  end
end
