# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "galleruby/version"

Gem::Specification.new do |s|
  s.name        = "galleruby"
  s.version     = Galleruby::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jørgen P. Tjernø"]
  s.email       = ["jorgenpt@gmail.com"]
  s.homepage    = "https://github.com/jorgenpt/galleruby"
  s.summary     = %q{A tool to automatically generate a static HTML gallery}
  s.description = %q{Galleruby allows you to automatically generate a static HTML gallery from a set of directories containing photos - each directory an album.
  It is indended to allow you to publish this on static file hosts like Amazon S3.}

  s.rubyforge_project = "galleruby"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'haml'
  s.add_dependency 'rmagick'
end
