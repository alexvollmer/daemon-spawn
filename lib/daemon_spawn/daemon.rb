require 'fileutils'

require 'daemon_spawn/logger'

# Large portions of this were liberally stolen from the
# 'simple-daemon' project at http://simple-daemon.rubyforge.org/
module DaemonSpawn

  module Daemon
    include DaemonSpawn::Logger

    def self.usage(msg=nil) #:nodoc:
      say :info, "#{msg}, " if msg
      say :info, "usage: #{$0} <command> [options]"
      say :info, "Where <command> is one of start, stop, restart or status"
      say :info, "[options] are additional options passed to the underlying process"
    end

    def self.alive?(pid)
      Process.kill 0, pid
    rescue Errno::ESRCH
      false
    end

    def self.start(daemon, args) #:nodoc:
      if !File.writable?(File.dirname(daemon.log_file))
        say :error, "Unable to write log file to #{daemon.log_file}"
        exit 1
      end

      if !File.writable?(File.dirname(daemon.pid_file))
        say :error, "Unable to write PID file to #{daemon.pid_file}"
        exit 1
      end

      if daemon.alive? && daemon.singleton
        say :error, "An instance of #{daemon.app_name} is already " +
          "running (PID #{daemon.pid})"
        exit 0
      end

      fork do
        Process.setsid
        exit if fork

        open(daemon.pid_file, 'w') { |f| f << Process.pid }
        Dir.chdir daemon.working_dir
        File.umask 0000

        log = File.new(daemon.log_file, "a")
        log.sync = daemon.sync_log

        STDIN.reopen "/dev/null"
        STDOUT.reopen log
        STDERR.reopen STDOUT

        trap("TERM") {daemon.stop; exit}
        daemon.start(args)
      end

      puts "#{daemon.app_name} started."
    end

    def self.stop(daemon) #:nodoc:
      if pid = daemon.pid

        FileUtils.rm(daemon.pid_file)
        Process.kill(daemon.signal, pid)

        begin
          Process.wait(pid)
        rescue Errno::ECHILD
        end

        if ticks = daemon.timeout

          while ticks > 0 and alive?(pid)
            say :info, "Process is still alive. #{ticks} seconds until I kill -9 it..."
            sleep 1
            ticks -= 1
          end

          if alive?(pid)
            say :info, "Process didn't quit after timeout of #{daemon.timeout} seconds. Killing..."
            Process.kill 9, pid
          end

        end

      else
        say :info, "PID file not found. Is the daemon started?"
      end

    rescue Errno::ESRCH
      say :info, "PID file found, but process was not running. The daemon may have died."
    end

    def self.status(daemon) #:nodoc:
      say :info, "#{daemon.app_name} is #{daemon.alive? ? "" : "NOT "}running (PID #{daemon.pid})"
    end


  end # class Daemon

end # module DaemonSpawn
