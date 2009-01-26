#!/usr/bin/env ruby

require 'daemon-spawn'
require 'socket'

class EchoServer < DaemonSpawn::Base

  attr_accessor :server_socket

  def start(args)
    port = args.empty? ? 0 : args.first.to_i
    self.server_socket = TCPServer.new('127.0.0.1', port)
    port = self.server_socket.addr[1]
    puts "EchoServer started on port #{port}"
    loop do
      begin
        client = self.server_socket.accept
        while str = client.gets
          client.write(str)
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

EchoServer.spawn!(:working_dir => File.join(File.dirname(__FILE__), '..'),
                  :log_file => '/tmp/echo_server.log',
                  :pid_file => '/tmp/echo_server.pid',
                  :sync_log => true,
                  :singleton => true)
