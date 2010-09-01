#!/usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), "..", "..", "lib"))

require "daemon_spawn"
require "socket"
require "tmpdir"

# An echo server using daemon-spawn. It starts up local TCP server
# socket and repeats each line it receives on the connection. To fire
# it up run:
#   ./echo_server.rb start 12345
# Then connect to it using telnet to test it:
#   telnet localhost 12345
#   > howdy!
#   howdy!
# to shut the daemon down, go back to the command-line and run:
#  ./echo_server.rb stop
class EchoServer < DaemonSpawn::Base

  attr_accessor :server_socket

  def start(args)
    port = args.empty? ? 0 : args.first.to_i
    self.server_socket = TCPServer.new('127.0.0.1', port)
    self.server_socket.setsockopt(Socket::SOL_SOCKET,
                                  Socket::SO_REUSEADDR,
                                  true)
    port = self.server_socket.addr[1]
    puts "EchoServer started on port #{port}"
    loop do
      begin
        client = self.server_socket.accept
        puts "Got a connection from #{client}"
        while str = client.gets
          client.write(str)
          puts "Echoed '#{str}' to #{client}"
        end
      rescue Errno::ECONNRESET => e
        STDERR.puts "Client reset connection"
      end
    end
  end

  def stop
    puts "Stopping EchoServer..."
    self.server_socket.close if self.server_socket
  end
end

EchoServer.spawn!(:working_dir => File.join(File.dirname(__FILE__), '..', '..'),
                  :log_file => File.join(Dir.tmpdir, 'echo_server.log'),
                  :pid_file => File.join(Dir.tmpdir, 'echo_server.pid'),
                  :sync_log => true,
                  :singleton => true)
