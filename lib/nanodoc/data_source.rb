require 'set'
require 'mahoro'
require 'minigit'
require 'pathname'

require 'nanoc'

require 'nanodoc/util'

module NanoDoc

##
## Nanodoc::DataSource
## ===================
##

  class DataSource < Nanoc::DataSource
    include Nanoc::DataSources::Filesystem
    extend Nanoc::Memoization

    identifier :nanodoc

##
## Nanoc methods
## -------------
##

    def items
      source_prefix_length = source_realpath.to_s.length + 1
      interesting_files.map do |filename|
        pathname = Pathname.new(filename)
        attributes = { :filename => filename,
                       :pathname => pathname,
                       :extension => pathname.extname[1..-1],
                       :mime_type => mahoro.file(filename) }
        identifier = identifier_for_filename(pathname.relative_path_from(source_realpath))
        mtime = pathname.stat.mtime
        is_binary = attributes[:mime_type] !~ /^(text\/|application\/xml)/
        content = is_binary ? filename : read(filename)
        Nanoc::Item.new( content, attributes, identifier,
          :binary => is_binary,
          :mtime => mtime )
      end
    end

##

    def identifier_for_filename(filename)
      filename.to_s.sub(/(^|\/)README(\.[^\.\/]+)?$/, '').cleaned_identifier
    end

##

    def filename_for(base_filename, ext)
      case ext
      when nil then nil
      when '' then base_filename
      else "#{base_filename}.#{ext}"
      end
    end

##
## Helper methods, internal logic
## ------------------------------
##

    def interesting_files
      # Start with a set of all files in `dir_name` given to us by
      # our superclass
      files = Set.new(all_files_in(source_realpath.to_s).
        map! { |filename| Pathname.new(filename) })

      # We cache mapping of realpath to "our" file name, to allow
      # other ignoring rules work on full file names. Key is a
      # realpath as string, value is array of files having that
      # realpath.
      realpath_files = {}

      fs_root = Pathname.new('/')
      files.each do |path|
        realpath = path.realpath
        if ignored?(realpath)
          files.delete(path)
        else
          realpath_s = realpath.to_s
          realpath_files[realpath_s] ||= []
          realpath_files[realpath_s] << path
        end
      end

      # Reject a list of realpaths from files that are ignored by git
      if use_gitignore?
        git_root = Pathname.new(git.git_work_tree)
        files.each_slice(512) do |some_files|
          gitignored_real =
            git.ls_files( { :others => true,
                            :ignored => true,
                            :exclude_standard => true,
                            :full_name => true },
                          '--', *some_files ).lines.map do |ln|
            git_root.join(ln.strip).realpath.to_s
          end
          gitignored_files = realpath_files.values_at(*gitignored_real)
          gitignored_files.flatten!
          files.subtract(gitignored_files)
        end
      end

      files
    end

    # `path` should be a realpath string
    def ignored?(path)
      # Ignore files that are in the output directory
      return true unless '..' == path.relative_path_from(output_realpath).descend { |p| break p.to_s }

      path = Pathname.new(path).relative_path_from(source_realpath)

      # Ignore files that are above base directory (`break`ing from
      # `Pathname#descend` gives us first element on the path)
      return true if '..' == path.descend { |p| break p.to_s }

      # Absolutize the relative path by attaching it to filesystem
      # root.
      path = Pathname.new('/').join(path)

      # Finally, ignore if any of configured ignore patterns match.
      @site.config[:ignore].any? { |pattern| path.fnmatch?(pattern) }
    end

##
## Accessors and cached stuff
## --------------------------
##

    def use_gitignore?
      if @site.config.key?(:use_gitignore)
        @site.config[:use_gitignore]
      else
        source_realpath.join('.git').exist?
      end
    end
    memoize :use_gitignore?

    def git
      MiniGit::Capturing.new(source_realpath.to_s)
    end
    memoize :git

    def mahoro
      Mahoro.new(Mahoro::MIME)
    end
    memoize :mahoro

    def source_realpath
      Pathname.new(@site.config[:source_dir]).realpath
    end
    memoize :source_realpath

    def output_realpath
      Nanodoc::Util.would_be_realpath(Pathname.new(@site.config[:output_dir]))
    end
    memoize :output_realpath
  end
end
