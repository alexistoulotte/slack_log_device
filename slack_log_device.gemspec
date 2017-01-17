Gem::Specification.new do |s|
  s.name = 'slack_log_device'
  s.version = File.read("#{File.dirname(__FILE__)}/VERSION").strip
  s.platform = Gem::Platform::RUBY
  s.author = 'Alexis Toulotte'
  s.email = 'al@alweb.org'
  s.homepage = 'https://github.com/alexistoulotte/slack_log_device'
  s.summary = 'LogDevice for Slack'
  s.description = 'LogDevice implementation that post logs on a Slack channel'
  s.license = 'MIT'

  s.rubyforge_project = 'slack_log_device'

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_development_dependency 'byebug', '>= 9.0.0', '< 10.0.0'
  s.add_development_dependency 'rake', '>= 12.0.0', '< 13.0.0'
  s.add_development_dependency 'rspec', '>= 3.5.0', '< 3.6.0'
end