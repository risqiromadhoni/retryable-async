# frozen_string_literal: true

require_relative 'lib/retryable-async'

Gem::Specification.new do |s|
  s.name = 'retryable-async'
  s.summary = 'Unified retry helper for sync and async Ruby contexts'
  s.version = Retryable::VERSION
  s.authors = ['Risqi Romadhoni']
  s.email = 'me@heyris.me'
  s.homepage = 'https://github.com/risqiromadhoni/retryable-async/'
  s.licenses = ['MIT']

  s.description = <<~DESCRIPTION
    retryable-async provides a lightweight retry mechanism
    compatible with Async and Fiber-based Ruby environments.
  DESCRIPTION

  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 3.0.0'

  s.require_paths = ['lib']

  s.files = [
    'LICENSE',
    'README.md'
  ] + Dir.glob('lib/**/*.rb') + Dir.glob('spec/**/*.rb')
end
