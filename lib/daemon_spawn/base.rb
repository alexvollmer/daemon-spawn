require 'daemon_spawn/daemon'
require 'daemon_spawn/logger'

module DaemonSpawn

  class Base
    include DaemonSpawn::Logger

    attr_accessor :log_file, :pid_file, :sync_log
    attr_accessor :working_dir, :app_name, :singleton
    attr_accessor :index, :signal, :timeout, :verbose

    def initialize(options={})
      raise 'You must specify a :working_dir' unless options[:working_dir]

      enable_daemon_verbosity options[:verbose]

      self.working_dir = options[:working_dir]

      self.app_name = options[:application] || classname

      self.pid_file = options[:pid_file] || File.join(working_dir, 'tmp', 'pids', app_name + '.pid')
      self.log_file = options[:log_file] || File.join(working_dir, 'logs', app_name + '.log')

      self.signal = options[:signal] || 'TERM'
      self.timeout = options[:timeout]

      self.index = options[:index] || 0

      if self.index > 0
        self.pid_file += ".#{self.index}"
        self.log_file += ".#{self.index}"
      end

      self.sync_log = options[:sync_log]
      self.singleton = options[:singleton] || false
    end

    def classname #:nodoc:
      name = self.class.to_s.split('::').last
      return name unless name == "Base"
      "Daemon(s)"
    end

    #
    # Provide your implementation. These are provided as a reminder
    # only and will raise an error if invoked. When started, this
    # method will be invoked with the remaining command-line arguments.
    #
    def start(args)
      raise "You must implement a 'start' method in your class!"
    end

    #
    # Provide your implementation. These are provided as a reminder
    # only and will raise an error if invoked.
    #
    def stop
      raise "You must implement a 'stop' method in your class!"
    end

    def self.find(options)
      pid_file = new(options).pid_file
      basename = File.basename(pid_file).split('.').first

      pid_files = Dir.glob(File.join(File.dirname(pid_file), "#{basename}.*pid*"))
      pid_files.map { |f| new(options.merge(:pid_file => f)) }
    end

    #
    # Invoke this method to process command-line args and dispatch
    # appropriately. Valid options include the following _symbols_:
    #
    # - <tt>:working_dir</tt> -- the working directory (required)
    # - <tt>:log_file</tt> -- path to the log file
    # - <tt>:pid_file</tt> -- path to the pid file
    # - <tt>:sync_log</tt> -- indicate whether or not to sync log IO
    # - <tt>:singleton</tt> -- If set to true, only one instance is
    #
    # allowed to start
    # args must begin with 'start', 'stop', 'status', or 'restart'.
    # The first token will be removed and any remaining arguments
    # passed to the daemon's start method.
    #
    def self.spawn!(opts = {}, args = ARGV)
      case args.any? and command = args.shift
      when 'start', 'stop', 'status', 'restart'

        send(command, opts, args)
        
      when '-h', '--help', 'help'
        Daemon.usage
        exit
      else
        Daemon.usage "Invalid command"
        exit 1
      end
    end

    def self.start(opts, args)
      living_daemons = find(opts).select { |d| d.alive? }

      if living_daemons.any?
        base = Base.new(opts)
        say :info, "#{base.app_name} already started! PIDS: #{living_daemons.map {|d| d.pid}.join(', ')}"
        exit 1
      else
        build(opts).map { |d| Daemon.start(d, args) }
      end

    end

    def self.stop(opts, args)
      daemons = find(opts)

      if daemons.empty?
        say :error, "No PID files found. Is the daemon started?"
        exit 1
      else
        daemons.each { |d| Daemon.stop(d) }
      end

    end

    def self.status(opts, args)
      daemons = find(opts)

      if daemons.empty?
        say :info, "No PIDs found"
      else
        daemons.each { |d| Daemon.status(d) }
      end

    end

    def self.restart(opts, args)
      daemons = build(opts)

      daemons.map do |daemon|
        Daemon.stop(daemon)
        Daemon.start(daemon, args)
      end

    end

    def self.build(options)
      count = options.delete(:processes) || 1

      daemons = []
      count.times do |index|
        daemons << new(options.merge(:index => index))
      end

      daemons
    end

    def alive? #:nodoc:
      if File.file?(pid_file)
        Daemon.alive? pid
      else
        false
      end
    end

    def pid #:nodoc:
      IO.read(self.pid_file).to_i rescue nil
    end

  end # class Base

end # module DaemonSpawn
