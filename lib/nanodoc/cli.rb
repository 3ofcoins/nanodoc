require 'thor'

require 'nanodoc'

class Nanodoc::CLI < Thor
  default_task :compile

  desc :compile, "Compile the documentation"
  def compile
    site = Nanodoc::Site.new

    say "Loading site data..."
    site.load

    say "Compiling site..."
    site.compile

    say "Done."
  end
end
