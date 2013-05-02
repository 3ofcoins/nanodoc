# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nanodoc/version'

Gem::Specification.new do |gem|
  gem.name          = "nanodoc"
  gem.version       = Nanodoc::VERSION
  gem.authors       = ["Maciej Pasternacki"]
  gem.email         = ["maciej@pasternacki.net"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "nanoc"
  gem.add_dependency "kramdown"
  gem.add_dependency "adsf"
  gem.add_dependency "rocco"
  gem.add_dependency "mahoro"
  gem.add_dependency "haml"
  gem.add_dependency "rubypants"
  gem.add_dependency "deep_merge"

  gem.add_development_dependency "minitest"
  gem.add_development_dependency "rake"
end
