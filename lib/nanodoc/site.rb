require 'pathname'
require 'yaml'

require 'deep_merge'
require 'nanoc'

require 'nanodoc/util'
require 'nanodoc/version'

module Nanodoc
  class Site < Nanoc::Site
    ROOT_DIR = Pathname.new(__FILE__).dirname.join('../../site').realpath

    def self.config(custom_config=nil, *custom_configs)
      config = {
        :source_dir => '.',
        :output_dir => 'doc/public',
        :site_root => ROOT_DIR.to_s,
        :data_sources => [
          { :type => 'nanodoc',
            :items_root => '/',
            :layouts_root => '/' },
          { :type => 'static',
            :prefix => ROOT_DIR.join('static').to_s,
            :items_root => '/_static/' } ],
        :ignore => [],
        :nanodoc => {
          :version => Nanodoc::VERSION
        }}

      custom_config ||= [
        '.nanodoc.yaml',
        '.nanodoc.yml',
        'nanodoc.yaml',
        'nanodoc.yml',
        'config/nanodoc.yaml',
        'config/nanodoc.yml'
      ].find { |file| File.exists?(file) }

      custom_configs.unshift(custom_config)

      custom_configs.each do |custom_config|
        case custom_config
        when nil
          custom_config = {}
        when Hash
          # we've got literal options, do nothing with them
        when String
          config[:config_path] = custom_config
          custom_config = YAML::load_file(custom_config).symbolize_keys_recursively
        else
          raise ArgumentError, "Expected nil, string or hash - got #{custom_config.inspect}"
        end

        config.deep_merge!(custom_config)
      end

      config[:source_dir] = File.realpath(config[:source_dir])
      config[:output_dir] = Nanodoc::Util.would_be_realpath(config[:output_dir])
      config[:project_name] ||= File.basename(config[:source_dir])

      if ENV['DEBUG']
        require 'pp'
        pp config
      end

      config
    end

    def initialize(config=nil, *more_configs)
      super(self.class.config(config, *more_configs))
    end

    def load
      Dir.chdir(config[:site_root]) do
        super
      end
    end
  end
end
