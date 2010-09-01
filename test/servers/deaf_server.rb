#!/usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), "..", "..", "lib"))

require "daemon_spawn"
require "tmpdir"

# A server that only quits if you send it SIGWINCH
class DeafServer < DaemonSpawn::Base
  def start(args)
    trap('TERM') { }
    trap('INT')  { }
    trap('SIGWINCH') { exit 0 }
    loop do
      sleep 100
    end
  end

  def stop
  end
end

DeafServer.spawn!(:working_dir => File.join(File.dirname(__FILE__), '..', '..'),
                  :log_file => File.join(Dir.tmpdir, 'deaf_server.log'),
                  :pid_file => File.join(Dir.tmpdir, 'deaf_server.pid'),
                  :sync_log => true,
                  :singleton => true,
                  :signal => 'SIGWINCH')
