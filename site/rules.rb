#!/usr/bin/env ruby

preprocess do
  fill_missing_directories
  @items['/'][:label] = File.basename(@config[:source_dir])
end

compile '/_static*' do
  # Leave static files alone
end

compile '*' do
  if item.binary?
    # Leave binaries alone
  else
    case item[:extension]
    when 'md'
      filter :kramdown
      filter :rubypants
    when 'txt', 'text', nil
      filter :txt
    else
      filter :literate_pyg unless item[:directory?]
    end
    layout 'default.haml'
    filter :relativize_paths, :type => :html
  end
end

route '/_static*' do
  item.identifier.chop
end

route '*' do
  item.identifier + 'index.html'
end

layout '*', :haml, :format => :html5