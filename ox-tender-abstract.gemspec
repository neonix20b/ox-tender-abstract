# frozen_string_literal: true

require_relative 'lib/oxtenderabstract/version'

Gem::Specification.new do |spec|
  spec.name = 'ox-tender-abstract'
  spec.version = OxTenderAbstract::VERSION
  spec.authors = ['smolev']
  spec.email = ['s.molev@gmail.com']

  spec.summary = 'Ruby library for working with Russian tender system (zakupki.gov.ru) SOAP API'
  spec.description = 'A modular Ruby library that provides a clean interface for fetching and parsing tender data from zakupki.gov.ru through SOAP-XML API. Returns structured hash results with tender information.'
  spec.homepage = 'https://github.com/smolev/ox-tender-abstract'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/smolev/ox-tender-abstract'
  spec.metadata['changelog_uri'] = 'https://github.com/smolev/ox-tender-abstract/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # SOAP API dependencies
  spec.add_dependency 'nokogiri', '~> 1.15'
  spec.add_dependency 'savon', '~> 2.14'

  # Archive processing dependencies
  spec.add_dependency 'rubyzip', '~> 2.3'

  # HTTP client
  spec.add_dependency 'net-http', '>= 0.3.0'

  # Development dependencies
  spec.add_development_dependency 'irb', '~> 1.8'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rdoc', '~> 6.5'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.21'
  spec.add_development_dependency 'vcr', '~> 6.1'
  spec.add_development_dependency 'webmock', '~> 3.18'
end
