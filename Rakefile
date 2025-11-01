# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

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

namespace :rbs do
  desc 'Validate all RBS files for syntax and consistency'
  task :validate do
    sh 'bundle exec rbs validate'
  end

  desc 'Type check Ruby files using Steep'
  task :check do
    if File.exist?('Steepfile')
      sh 'bundle exec steep check'
    else
      puts '⚠️  No Steepfile found — skipping type check'
    end
  end

  desc 'Generate RBS prototypes from Ruby sources'
  task :prototype do
    lib_files = FileList['lib/**/*.rb']
    lib_files.each do |path|
      sig_path = path.sub(%r{^lib/}, 'sig/').sub(/\.rb$/, '.rbs')
      mkdir_p File.dirname(sig_path)
      sh "bundle exec rbs prototype rb #{path} > #{sig_path}"
    end
  end
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

    puts 'Validating RBS signatures...'
    Rake::Task['rbs:validate'].execute

    puts '✓ Ready for release!'
  end
end

desc 'Run all quality checks (tests + linting)'
task quality: %i[spec rubocop rbs:validate]

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

require 'rdoc/task'
desc 'Generate documentation using rdoc'
RDoc::Task.new do |doc|
  doc.main = 'README.rdoc'
  doc.title = 'retryable-async -- Unified retry helper for sync and async Ruby contexts'
  doc.rdoc_files = FileList.new %w[lib LICENSE doc/**/*.rdoc *.rdoc]
  doc.rdoc_dir = '_site'
end

task default: %i[spec rubocop rbs:validate]
