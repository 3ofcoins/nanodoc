require 'set'

module Nanodoc

  NO_README = <<EOF
<div class="well well-large">
  <p class="text-center lead">
    No <em>README</em> file here.
  </p>
</div>
EOF

  module Helpers
    include Nanoc::Helpers::Breadcrumbs
    include Nanoc::Helpers::HTMLEscape
    include Nanoc::Helpers::LinkTo

    def fill_missing_directories
      ids = Set.new( @items.map(&:identifier) )
      ids_with_intermediate_dirs = ids.map do |identifier|
        path_elements = identifier.split('/')
        (0..path_elements.length).map do |i|
          path_elements[0..i].join('/') << '/'
        end
      end
      ids_with_intermediate_dirs = Set.new(ids_with_intermediate_dirs.flatten)
      missing_intermediate_dirs = ids_with_intermediate_dirs - ids

      missing_intermediate_dirs.each do |dir_id|
        @items << Nanoc::Item.new(NO_README,
          {:mime_type => 'text/html', :extension => 'html', :directory? => true, :pathname => dir_id.chop},
          dir_id,
          :binary => false)
      end
    end

    def link_to_file(item, attributes={})
      link_to(item.label, (item.children.find(&:readme?) || item), attributes)
    end
  end
end
