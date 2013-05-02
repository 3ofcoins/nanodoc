require 'pathname'
require 'yaml'

require 'deep_merge'
require 'nanoc'

require 'nanodoc/util'

module Nanodoc
  class Site < Nanoc::Site
    ROOT_DIR = Pathname.new(__FILE__).dirname.join('../../site').realpath

    def self.config(config={})
      config = YAML::load_file(config) if config.is_a?(String)
      { :source_dir => Dir.pwd,
        :output_dir => File.join(Dir.pwd, 'doc'),
        :site_root => ROOT_DIR.to_s,
        :data_sources => [
          { :type => 'nanodoc',
            :items_root => '/',
            :layouts_root => '/' },
          { :type => 'static',
            :prefix => ROOT_DIR.join('static').to_s,
            :items_root => '/_static/' } ],
        :ignore => []
      }.deep_merge!(config)
    end

    def initialize(source_dir, output_dir, options={})
      super(self.class.config(source_dir, output_dir, options))
    end

    def load
      Dir.chdir(config[:site_root]) do
        super
      end
    end
  end
end
