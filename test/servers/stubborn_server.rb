#!/usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), "..", "..", "lib"))

require "daemon_spawn"
require "tmpdir"

# A server that needs to be kill -9'ed
class StubbornServer < DaemonSpawn::Base
  def start(args)
    trap('TERM') { }
    loop do
      sleep 100
    end
  end

  def stop
    raise "You should never get to me"
  end
end

StubbornServer.spawn!(:working_dir => File.join(File.dirname(__FILE__), '..', '..'),
                      :log_file => File.join(Dir.tmpdir, 'stubborn_server.log'),
                      :pid_file => File.join(Dir.tmpdir, 'stubborn_server.pid'),
                      :sync_log => true,
                      :singleton => true,
                      :timeout => 2)
