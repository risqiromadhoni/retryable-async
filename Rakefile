# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

# Default task: run tests
task default: %i[spec rubocop]

# RSpec tests
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = '--format documentation --color'
end

# RuboCop linting
RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names', '--extra-details', '--format', 'progress']
  t.fail_on_error = true
end

# Auto-correct RuboCop offenses
RuboCop::RakeTask.new('rubocop:autocorrect') do |t|
  t.options = ['--autocorrect-all']
  t.fail_on_error = false
end

# Generate RuboCop TODO for new cops
namespace :rubocop do
  desc 'Auto-generate .rubocop_todo.yml'
  task :auto_gen_config do
    sh 'bundle exec rubocop --auto-gen-config --auto-gen-only-exclude --exclude-limit 100'
  end
end

namespace :spec do
  desc 'Run tests with verbose output'
  RSpec::Core::RakeTask.new(:verbose) do |t|
    t.pattern = 'spec/**/*_spec.rb'
    t.rspec_opts = '--format documentation --color --backtrace'
  end

  desc 'Run tests with coverage'
  task :coverage do
    ENV['COVERAGE'] = 'true'
    Rake::Task['spec'].execute
  end
end

namespace :changelog do
  desc 'Generate CHANGELOG from git commits'
  task :generate do
    sh 'github_changelog_generator --user risqiromadhoni --project retryable-async'
  end

  desc 'Update CHANGELOG for unreleased changes'
  task :update do
    sh 'github_changelog_generator --user risqiromadhoni --project retryable-async --unreleased-only'
  end
end

namespace :release do
  desc 'Check if ready for release'
  task :check do
    puts 'Checking if ready for release...'

    # Check if working directory is clean
    unless system('git diff-index --quiet HEAD --')
      abort 'Working directory is not clean. Commit or stash changes first.'
    end

    # Check if on main/master branch
    current_branch = `git branch --show-current`.strip
    abort "Not on main/master branch. Current branch: #{current_branch}" unless %w[main master].include?(current_branch)

    # Run tests
    puts 'Running tests...'
    Rake::Task['spec'].execute

    # Run linting
    puts 'Running RuboCop...'
    Rake::Task['rubocop'].execute

    puts '✓ Ready for release!'
  end
end

desc 'Run all quality checks (tests + linting)'
task quality: %i[spec rubocop]

desc 'Setup development environment'
task :setup do
  puts 'Installing dependencies...'
  sh 'bundle install'

  puts 'Setting up git hooks with lefthook...'
  sh 'lefthook install'

  puts '✓ Development environment ready!'
end

desc 'Clean up build artifacts'
task :clean do
  sh 'rm -rf pkg/' if File.directory?('pkg')
  sh 'rm -rf coverage/' if File.directory?('coverage')
  puts '✓ Cleaned build artifacts'
end

desc 'Display gem version'
task :version do
  require_relative 'lib/retryable-async'
  puts "retryable-async version: #{Retryable::VERSION}"
end
