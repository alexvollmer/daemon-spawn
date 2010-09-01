#!/usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), "..", "..", "lib"))

require "daemon_spawn"

class TapsServer < DaemonSpawn::Base
  def start(args)
    sleep 5 # Sinatra takes its sweet time to shut down
    Kernel.exec "/usr/bin/taps server mysql://dbusername:dbpassword@localhost/data1_production?encoding=utf8 username password"
  end

  def stop
  end
end
TapsServer.spawn!(:working_dir => File.join(File.dirname(__FILE__), '..', '..'),
                  :log_file => File.join(Dir.tmpdir, 'taps_server.log'),
                  :pid_file => File.join(Dir.tmpdir, 'taps_server.pid'),
                  :sync_log => true,
                  :singleton => true,
                  :signal => 'INT') # Sinatra ignores TERM
