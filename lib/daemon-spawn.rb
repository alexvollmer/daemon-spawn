require "fileutils"

# Large portions of this were liberally stolen from the
# 'simple-daemon' project at http://simple-daemon.rubyforge.org/
module DaemonSpawn
  VERSION = '0.2.0'

  def self.usage(msg=nil) #:nodoc:
    print "#{msg}, " if msg
    puts "usage: #{$0} <command> [options]"
    puts "Where <command> is one of start, stop, restart or status"
    puts "[options] are additional options passed to the underlying process"
  end

  def self.start(daemon, args) #:nodoc:
    if !File.writable?(File.dirname(daemon.log_file))
      STDERR.puts "Unable to write log file to #{daemon.log_file}"
      exit 1
    end

    if !File.writable?(File.dirname(daemon.pid_file))
      STDERR.puts "Unable to write log file to #{daemon.pid_file}"
      exit 1
    end

    if daemon.alive? && daemon.singleton
      STDERR.puts "An instance of #{daemon.classname} is already " +
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
    puts "#{daemon.classname} started."
  end

  def self.stop(daemon) #:nodoc:
    if pid = daemon.pid
      FileUtils.rm(daemon.pid_file)
      Process.kill("TERM", pid)
      begin
        Process.wait(pid)
      rescue Errno::ECHILD
      end
    else
      puts "Pid file not found. Is the daemon started?"
    end
  rescue Errno::ESRCH
    puts "Pid file found, but process was not running. The daemon may have died."
  end

  def self.status(daemon) #:nodoc:
    if daemon.alive?
      puts "#{daemon.classname} is running (PID #{PidFile.recall(daemon)})"
    else
      puts "#{daemon.classname} is NOT running"
    end
  end

  class Base
    attr_accessor :log_file, :pid_file, :sync_log, :working_dir, :singleton

    def initialize(opts={ })
      raise "You must specify a :working_dir" unless opts[:working_dir]
      self.working_dir = opts[:working_dir]

      self.log_file = opts[:log_file] || File.join(self.working_dir, 'logs', self.classname + '.log')
      self.pid_file = opts[:pid_file] || File.join(self.working_dir, 'run', self.classname + '.pid')
      self.sync_log = opts[:sync_log]
      self.singleton = opts[:singleton] || false
    end

    def classname #:nodoc:
      self.class.to_s.split('::').last
    end

    # Provide your implementation. These are provided as a reminder
    # only and will raise an error if invoked. When started, this
    # method will be invoked with the remaining command-line arguments.
    def start(args)
      raise "You must implement a 'start' method in your class!"
    end

    # Provide your implementation. These are provided as a reminder
    # only and will raise an error if invoked.
    def stop
      raise "You must implement a 'stop' method in your class!"
    end

    def alive? #:nodoc:
      if File.file?(self.pid_file)
        begin
          Process.kill(0, self.pid)
        rescue Errno::ESRCH, ::Exception
          false
        end
      else
        false
      end
    end

    def pid #:nodoc:
      IO.read(self.pid_file).to_i rescue nil
    end

    # Invoke this method to process command-line args and dispatch
    # appropriately. Valid options include the following _symbols_:
    # - <tt>:working_dir</tt> -- the working directory (required)
    # - <tt>:log_file</tt> -- path to the log file
    # - <tt>:pid_file</tt> -- path to the pid file
    # - <tt>:sync_log</tt> -- indicate whether or not to sync log IO
    # - <tt>:singleton</tt> -- If set to true, only one instance is
    # allowed to start
    # args must begin with 'start', 'stop', 'status', or 'restart'.
    # The first token will be removed and any remaining arguments
    # passed to the daemon's start method.
    def self.spawn!(opts={ }, args=ARGV)
      case args.size > 0 && args.shift
      when 'start'
        daemon = self.new(opts)
        DaemonSpawn.start(daemon, args)
      when 'stop'
        daemon = self.new(opts)
        DaemonSpawn.stop(daemon)
      when 'status'
        daemon = self.new(opts)
        if daemon.alive?
          puts "#{daemon.classname} is running (#{daemon.pid})"
        else
          puts "#{daemon.classname} is NOT running"
        end
      when 'restart'
        daemon = self.new(opts)
        DaemonSpawn.stop(daemon)
        DaemonSpawn.start(daemon, args)
      when '-h', '--help', 'help'
        DaemonSpawn.usage
        exit
      else
        DaemonSpawn.usage "Invalid command"
        exit 1
      end
    end
  end
end
