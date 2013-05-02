require 'pathname'
require 'redcarpet'
require 'rocco'

require 'nanodoc/site'

Rocco::Markdown = RedcarpetCompat

module Nanodoc
  class RoccoFilter < Nanoc::Filter
    identifier :rocco
    type :text

    LANGUAGES = {
      'text/x-ruby' => 'ruby',
      'text/x-shellscript' => 'sh',
      'text/x-m4' => 'text',
      'text/html' => 'html',
      'text/plain' => 'text'
    }

    def run(content, params={})
      language = case File.basename(@item[:filename])
                 when /\.(rb|pill)(\.in)?$/, /^(Gem|Rake|Thor|Berks|Vagrant|Vendor)file$/
                   'ruby'
                 when /\.(sh|init|default)(\.(in|erb))?$/
                   'sh'
                 when /\.json(\.in)?$/    then 'json'
                 when /\.p[lm]$/          then 'perl'
                 when /\.py$/             then 'python'
                 when /\.html(\.erb)?$/   then 'html'
                 when /\.xml(\.erb)?$/    then 'xml'
                 when /\.txt$/, /^[A-Z_]+$/
                   # FIXME: this shouldn't even be here
                   'text'
                 else
                   LANGUAGES[@item[:mime_type]] || 'text'
                 end
      Rocco.new(@item[:filename], [],
        :language => language,
        :template_file => File.join(config[:site_root], 'layouts', 'rocco.mustache')
        ).to_html
    end
  end
end
