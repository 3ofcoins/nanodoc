class Nanoc::Item
  def basename
    @_nanodoc_basename ||=
      File.basename(self[:filename] || self.identifier)
  end

  def label
    @_nanodoc_label ||= self[:label] || basename
  end

  def readme?
    self.basename =~ /^README(\.[^\.\/]+)?$/
  end

  def doc?
    self.basename =~ /^[A-Z_-]+(\.[^\.\/]+)?$/
  end

  def root_dir?
    self.identifier == '/'
  end

  def directory?
    !self[:filename]
  end

  def directory
    if self.directory?
      self
    else
      self.parent
    end
  end

  def siblings
    rv = self.directory.children.compact
    rv.delete_if { |item| item.identifier == '/_static/' }
    rv.sort_by do |sibling|
      tag = case
            # when sibling.readme? then 0
            when sibling.doc? then 1
            when sibling.directory? then 2
            else 3
            end
      "#{tag}#{sibling.basename}"
    end
  end
end
