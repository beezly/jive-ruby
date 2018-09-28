$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "jive/version"

Gem::Specification.new do |s|
  s.name        = 'jive_api'
  s.version     = Jive::VERSION
  s.summary     = "Jive API"
  s.description = "Jive API Connector for Ruby"
  s.authors     = ["Andrew Beresford", "Adam Drew", "Jon Roberts"]
  s.email       = "beezly@beezly.org.uk"

  s.require_paths = ["lib"]
  s.files = Dir.glob("lib/**/*")

  s.homepage    = "http://github.com/beezly/jive-ruby"
  s.add_dependency 'httparty', '>= 0.10.0'
  s.add_dependency 'hashery', '>= 2.1.0'
  s.add_dependency 'dalli'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
end
