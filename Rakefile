# frozen_string_literal: true

require 'bundler'
require 'rake/clean'
require 'rake/testtask'

Bundler::GemHelper.install_tasks

Rake::TestTask.new
task default: [:test]

desc 'Run unit tests'
task test: :set_rubyopts

desc 'Enable warnings'
task :set_rubyopts do
  ENV['RUBYOPT'] ||= ''
  ENV['RUBYOPT'] += ' -w'

  ENV['RUBYOPT'] += ' --enable-frozen-string-literal --debug=frozen-string-literal' if RUBY_ENGINE == 'ruby'
end
