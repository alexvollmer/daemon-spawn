#!/usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), "..", "..", "lib"))

require "daemon_spawn"

class SimpleServer < DaemonSpawn::Base

  attr_accessor :outfile

  def start(args)
    abort "USAGE: phrase_server.rb LOGFILE" if args.empty?
    @outfile = args.first
    self.puts "SimpleServer (#{self.index}) started"
    while true                  # keep running like a real daemon
      sleep 5
    end
  end

  def puts(str)
    open(@outfile, "a") { |f| f.puts str }
  end

  def stop
    self.puts "SimpleServer (#{self.index}) stopped"
  end

end

SimpleServer.spawn!(:working_dir => File.join(File.dirname(__FILE__), '..', '..'),
                    :log_file => '/tmp/simple_server.log',
                    :pid_file => '/tmp/simple_server.pid',
                    :sync_log => true,
                    :processes => 2)
