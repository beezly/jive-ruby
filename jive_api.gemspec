Gem::Specification.new do |s|
  s.name        = 'jive_api'
  s.version     = '0.0.1.pre'
  s.date        = '2013-03-13'
  s.summary     = "Jive API"
  s.description = "Jive API Connector for Ruby"
  s.authors     = ["Andrew Beresford"]
  s.email       = "beezly@beezly.org.uk"
  s.files       = ["lib/jive_api.rb"]
  s.homepage    = "http://github.com/beezly/jive-ruby"
  s.add_dependency 'httparty', '>= 0.10.0'
  s.add_dependency 'hashery', '>= 2.1.0'
  s.add_development_dependency 'rake'
end
