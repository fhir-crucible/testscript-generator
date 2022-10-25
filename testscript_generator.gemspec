# frozen_string_literal: true
Gem::Specification.new do |s|
    s.name = 'testscript_generator'
    s.version = '0.1.0'
    s.summary = 'A generator for creating FHIR TestScript resources using an IG'
    s.author = ['John Fraser']
    s.email = 'jfraser@mitre.org'
    s.license = 'Apache-2.0'
    s.add_runtime_dependency 'fhir_client', '~> 5.0.3'
    s.add_runtime_dependency 'fileutils', '~> 1.4.1'
    s.add_runtime_dependency 'package', '~> 0.0.1'
    s.add_runtime_dependency 'securerandom', '~> 0.2.0'
    s.add_runtime_dependency 'rubyzip', '~> 2.3.2'
    s.add_development_dependency 'pry-nav', '~> 1.0.0'
    s.add_development_dependency 'rspec', '~> 3.10'
    s.add_development_dependency 'webmock', '~> 3.10'
    s.required_ruby_version = Gem::Requirement.new('>= 2.7.0')
    s.files = [Dir['lib/**/*.rb']].flatten
    s.require_paths = ['lib']
    s.executables << "testscript_generator"
  end