# frozen_string_literal: true

require_relative 'lib/brainzlab/version'

Gem::Specification.new do |spec|
  spec.name = 'fluyenta-ruby'
  spec.version = BrainzLab::VERSION
  spec.authors = ['Fluyenta']
  spec.email = ['support@fluyenta.com']

  spec.summary = 'Ruby SDK for Fluyenta - Fork of BrainzLab Ruby SDK'
  spec.description = 'Ruby SDK for Fluyenta observability platform (fork of brainzlab-ruby). Includes Recall (structured logging), Reflex (error tracking), and Pulse (APM with distributed tracing). Auto-instruments Rails, Sidekiq, GraphQL, Redis, and more.'
  spec.homepage = 'https://fluyenta.com'
  spec.license = 'Nonstandard'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/fluyenta/fluyenta-ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/fluyenta/fluyenta-ruby/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://docs.fluyenta.com/sdk/ruby'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['github_repo'] = 'ssh://github.com/fluyenta/fluyenta-ruby'

  spec.files = Dir.chdir(__dir__) do
    Dir['{lib}/**/*', 'LICENSE', 'README.md', 'CHANGELOG.md']
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'concurrent-ruby', '~> 1.0'
  spec.add_dependency 'logger', '~> 1.5'
  spec.add_dependency 'sqlite3', '~> 2.0'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'webmock', '~> 3.0'
end