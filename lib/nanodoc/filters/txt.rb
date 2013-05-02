require 'nanoc/helpers/html_escape'

class TxtFilter < Nanoc::Filter
  identifier :txt
  type :text

  include Nanoc::Helpers::HTMLEscape

  def run(content, params={})
    "<pre>#{h(content)}</pre>"
  end
end
