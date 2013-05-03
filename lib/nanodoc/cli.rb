require 'fileutils'
require 'tmpdir'

require 'minigit'
require 'thor'

require 'nanodoc'

## Nanodoc::CLI
## ============
##
## Main command line interface to Nanodoc.

class Nanodoc::CLI < Thor
  default_task :compile

## compile(*configs)
## -----------------
## Compile the site to configured output directory.

  desc "compile [CONFIG_FILE [CONFIG_FILE ...]]",
       "Compile the documentation"
  def compile(*configs)
    @site = Nanodoc::Site.new(*configs)

    say "Loading site data..."
    @site.load

    say "Compiling site..."
    @site.compile

    say "Done."
  end

## gh_pages
## --------
##
## Compile documentation in a temporary directory, commit it as
## `gh-pages` branch, and push it to Git.
##
## It will probably fail miserably if you run it not from a git
## repository.

  desc :gh_pages, "Compile the documentation, commit it to gh-pages branch, and push"
  def gh_pages
    Dir.mktmpdir do |output_dir|
      # Use temporary directory to write to
      say "Working in temporary directory: #{output_dir}"
      compile(nil, :output_dir => output_dir)
      Dir.chdir(git.git_work_tree) do
        # Remember original branch and store changes.
        orig_branch = git.capturing.name_rev({:name_only => true}, 'HEAD').strip
        say "Stashing changes to #{orig_branch}..."
        git.stash :u => true, :a => true
        begin
          # Check out gh-pages if it exists, or create orphan branch
          # if there isn't one.
          say "Checking out and preparing gh-pages branch..."
          begin
            git.capturing.rev_parse({:verify => true, :quiet => true}, 'refs/heads/gh-pages')
          rescue MiniGit::GitError
            git.checkout({:orphan => true}, 'gh-pages')
          else
            git.checkout('gh-pages')
          end

          # Scrub the working branch clean.
          git.rm({:r => true, :f => true, :q => true, :ignore_unmatch => true}, '.')

          # Copy all the docs, and leave a `.nojekyll` file to make
          # GitHub serve the `/_static` directory.
          say "Copying documentation..."
          FileUtils::copy_entry output_dir, '.', true, true
          FileUtils::touch '.nojekyll'

          # Commit the docs and push them to GitHub
          say "Committing..."
          git.add '.'
          git.commit :message => 'rebuild docs'
          say "Pushing..."
          git.push 'origin', 'gh-pages'
        ensure
          # Even if something went wrong, try to make sure we're on
          # original branch and have unstashed the changes.
          say "Restoring original branch..."
          git.checkout orig_branch
          git.stash 'pop'
        end
      end
      say "All done."
    end
  end

## Private helpers
## ---------------

  private

  # Create or return a MiniGit instance.
  def git
    @git ||= MiniGit.new('.')
  end
end
