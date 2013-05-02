require 'pathname'

## Nanodoc::Util
## =============
##
## A collection of utility functions

module Nanodoc::Util

## would_be_realpath(path)
## -----------------------
##
## If `path` exists, return its realpath.  If `path` doesn't
## exist, climb up to find closest existing parent, get its
## realpath, and then join the missing part.
##
## This method returns a `Pathname` when given a `Pathname`, and
## a string when given a string.
  def self.would_be_realpath(path)
    return would_be_realpath(Pathname.new(path)).to_s unless path.is_a?(Pathname)
    path.realpath
  rescue Errno::ENOENT
    path = path.expand_path
    path.ascend do |prefix|
      realprefix = prefix.realpath rescue next
      break realprefix.join(path.relative_path_from(prefix))
    end
  end
end
