# -*- ruby -*-

require 'rubygems'

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'daemon_spawn'

require 'rake/testtask'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "daemon-spawn"
    gemspec.summary = "Daemon launching and management made dead simple"
    gemspec.description = %Q[With daemon-spawn you can start, stop and restart processes that run
    in the background. Processed are tracked by a simple PID file written
    to disk.]
    gemspec.rubyforge_project = "daemon-spawn"
    gemspec.email = "alex.vollmer@gmail.com"
    gemspec.homepage = "http://github.com/alexvollmer/daemon-spawn"
    gemspec.authors = ["Alex Vollmer", "Seamus Abshere", "Emmanual Gomez", "Seth Falcon", "Woody Peterson"]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install jeweler"
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*test.rb']
  t.verbose = true
end

# vim: syntax=Ruby
