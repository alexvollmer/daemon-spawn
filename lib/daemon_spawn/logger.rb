require 'daemon_spawn/logger'

module DaemonSpawn

  module Logger

    module LoggerMethods

      def enable_daemon_verbosity(verbosity=true)
        verbosity
      end

      def verbose?
        enable_daemon_verbosity
      end

      def say(type, message)
        case type.to_sym
        when :info
          puts message if verbose?
        when :error
          puts message
        end
      end

    end # module LoggerMethods

    def self.included(receiver)
      receiver.extend         LoggerMethods
      receiver.send :include, LoggerMethods
    end

  end # class Logger

end # module DaemonSpawn
