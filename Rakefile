# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

# Default task: run tests and linting
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

# RBS type checking (optional)
namespace :rbs do
  desc 'Validate all RBS files for syntax and consistency'
  task :validate do
    if Dir.exist?('sig')
      sh 'bundle exec rbs validate'
    else
      puts '⚠️  No sig/ directory found — skipping RBS validation'
    end
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

namespace :spec do
  desc 'Run tests with verbose output'
  RSpec::Core::RakeTask.new(:verbose) do |t|
    t.pattern = 'spec/**/*_spec.rb'
    t.rspec_opts = '--format documentation --color --backtrace'
  end

  desc 'Run tests with coverage'
  RSpec::Core::RakeTask.new(:coverage) do |t|
    t.pattern = 'spec/**/*_spec.rb'
    t.rspec_opts = '--format documentation --color'
    ENV['COVERAGE'] = 'true'
  end
end

namespace :changelog do
  desc 'Generate CHANGELOG (now automated by semantic-release)'
  task :generate do
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts '⚠️  CHANGELOG generation is now automated!'
    puts ''
    puts 'The CHANGELOG.md file is automatically updated by'
    puts 'semantic-release when you push to main branch.'
    puts ''
    puts 'Just use conventional commit messages:'
    puts '  • feat: for new features'
    puts '  • fix: for bug fixes'
    puts '  • docs: for documentation'
    puts ''
    puts 'The CHANGELOG will be updated automatically! 🎉'
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  end
end

namespace :release do
  desc 'Check if ready for release'
  task :check do
    puts 'Checking if ready for release...'

    # Check if working directory is clean
    unless system('git diff-index --quiet HEAD --')
      abort '❌ Working directory is not clean. Commit or stash changes first.'
    end

    # Check if on main/master branch
    current_branch = `git branch --show-current`.strip
    unless %w[main master].include?(current_branch)
      abort "❌ Not on main/master branch. Current branch: #{current_branch}"
    end

    # Run tests
    puts 'Running tests...'
    Rake::Task['spec'].execute

    # Run linting
    puts 'Running RuboCop...'
    Rake::Task['rubocop'].execute

    # Validate RBS if available
    if Dir.exist?('sig')
      puts 'Validating RBS signatures...'
      Rake::Task['rbs:validate'].execute
    end

    puts '✅ Ready for release!'
  end

  desc 'Show release information'
  task :info do
    require_relative 'lib/retryable/version'
    puts ''
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts "Current version: #{Retryable::VERSION}"
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts ''
    puts 'Releases are automated via semantic-release!'
    puts ''
    puts 'To trigger a release:'
    puts '  1. Use conventional commit messages'
    puts '  2. Push to main branch'
    puts '  3. GitHub Actions will handle the rest'
    puts ''
    puts 'Version bumps:'
    puts '  • feat: → Minor (0.1.0 → 0.2.0)'
    puts '  • fix: → Patch (0.1.0 → 0.1.1)'
    puts '  • BREAKING CHANGE: → Major (0.1.0 → 1.0.0)'
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts ''
  end
end

desc 'Run all quality checks (tests + linting)'
task :quality do
  Rake::Task['spec'].invoke
  Rake::Task['rubocop'].invoke
  Rake::Task['rbs:validate'].invoke if Dir.exist?('sig')
end

desc 'Setup development environment'
task :setup do
  puts 'Installing dependencies...'
  sh 'bundle install'

  if File.exist?('lefthook.yml')
    puts 'Setting up git hooks with lefthook...'
    begin
      sh 'lefthook install'
    rescue StandardError
      puts '⚠️  Lefthook not available, skipping...'
    end
  end

  puts '✅ Development environment ready!'
end

desc 'Clean up build artifacts'
task :clean do
  sh 'rm -rf pkg/' if File.directory?('pkg')
  sh 'rm -rf coverage/' if File.directory?('coverage')
  puts '✅ Cleaned build artifacts'
end

desc 'Display gem version'
task :version do
  require_relative 'lib/retryable/version'
  puts "retryable-async version: #{Retryable::VERSION}"
end

# Documentation generation (optional)
begin
  require 'rdoc/task'
  desc 'Generate documentation using rdoc'
  RDoc::Task.new do |doc|
    doc.main = 'README.md'
    doc.title = 'retryable-async -- Unified retry helper for sync and async Ruby contexts'
    doc.rdoc_files = FileList.new %w[lib/**/*.rb LICENSE README.md]
    doc.rdoc_dir = 'doc'
  end
rescue LoadError
  # RDoc not available, skip task
end
