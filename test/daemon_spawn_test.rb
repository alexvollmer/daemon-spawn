require File.join(File.dirname(__FILE__), "helper")
require "socket"

class DaemonSpawnTest < Test::Unit::TestCase

  SERVERS = File.join(File.dirname(__FILE__), "servers")

  # Try to make sure no pidfile (or process) is left over from another test.
  def setup
    %w{ echo_server deaf_server stubborn_server }.each do |server|
      begin
        Process.kill 9, possible_pid(server)
      rescue Errno::ESRCH
        # good, no process to kill
      end
      begin
        File.unlink pid_file(server)
      rescue Errno::ENOENT
        # good, no pidfile to clear
      end
    end
  end

  def with_socket
    socket = TCPSocket.new('127.0.0.1', 5150)
    socket.setsockopt(Socket::SOL_SOCKET,
                      Socket::SO_RCVTIMEO,
                      [1, 0].pack("l_2"))

    begin
      yield(socket) if block_given?
    ensure
      socket.close
    end
  end

  def echo_server(*args)
    `./echo_server.rb #{args.join(' ')}`
  end

  def while_running(&block)
    Dir.chdir(SERVERS) do
      `./echo_server.rb stop`
      assert_match(/EchoServer started./, `./echo_server.rb start 5150`)
      sleep 1
      begin
        with_socket &block
      ensure
        assert_match(//, `./echo_server.rb stop`)
        assert_raises(Errno::ECONNREFUSED) { TCPSocket.new('127.0.0.1', 5150) }
      end
    end
  end
  
  def after_daemon_dies_leaving_pid_file
    Dir.chdir(SERVERS) do
      `./echo_server.rb stop`
      sleep 1
      `./echo_server.rb start 5150`
      sleep 1
      leftover_pid = IO.read(pid_file('echo_server')).to_i
      Process.kill 9, leftover_pid
      sleep 1
      assert dead?(leftover_pid)
      assert File.exists?(pid_file('echo_server'))
      yield leftover_pid
    end
  end

  def test_daemon_running
    while_running do |socket|
      socket << "foobar\n"
      assert_equal "foobar\n", socket.readline
    end
  end

  def test_status_running
    while_running do |socket|
      assert_match(/EchoServer is running/, `./echo_server.rb status`)
    end
  end

  def test_status_not_running
    Dir.chdir(SERVERS) do
      assert_match(/No PIDs found/, `./echo_server.rb status`)
    end
  end

  def test_start_after_started
    while_running do
      pid = echo_server("status").match(/PID (\d+)/)[1]
      assert_match(/Daemons already started! PIDS: #{pid}/,
                   echo_server("start"))
    end
  end

  def test_stop_after_stopped
    Dir.chdir(SERVERS) do
      assert_match("No PID files found. Is the daemon started?",
                   `./echo_server.rb stop`)
    end
  end

  def test_restart_after_stopped
    Dir.chdir(SERVERS) do
      assert_match(/EchoServer started/, `./echo_server.rb restart 5150`)
      assert_equal(0, $?.exitstatus)
      sleep 1
      with_socket do |socket|
        socket << "foobar\n"
        assert_equal "foobar\n", socket.readline
      end
    end
  end

  def test_restart_after_started
    Dir.chdir(SERVERS) do
      assert_match(/EchoServer started/, `./echo_server.rb start 5150`)
      assert_equal(0, $?.exitstatus)
      sleep 1

      assert_match(/EchoServer started/, `./echo_server.rb restart 5150`)
      assert_equal(0, $?.exitstatus)
      sleep 1

      with_socket do |socket|
        socket << "foobar\n"
        assert_equal "foobar\n", socket.readline
      end
    end
  end
  
  def test_start_after_daemon_dies_leaving_pid_file
    after_daemon_dies_leaving_pid_file do |leftover_pid|
      assert_match /EchoServer started/, `./echo_server.rb start 5150`
      sleep 1
      new_pid = IO.read(pid_file('echo_server')).to_i
      assert new_pid != leftover_pid
      assert alive?(new_pid)
    end
  end

  def test_restart_after_daemon_dies_leaving_pid_file
    after_daemon_dies_leaving_pid_file do |leftover_pid|
      assert_match /EchoServer started/, `./echo_server.rb restart 5150`
      sleep 1
      new_pid = reported_pid 'echo_server'
      assert new_pid != leftover_pid
      assert alive?(new_pid)
    end
  end
  
  def test_stop_using_custom_signal
    Dir.chdir(SERVERS) do
      `./deaf_server.rb start`
      sleep 1
      pid = reported_pid 'deaf_server'
      assert alive?(pid)
      Process.kill 'TERM', pid
      sleep 1
      assert alive?(pid)
      Process.kill 'INT', pid
      sleep 1
      assert alive?(pid)
      `./deaf_server.rb stop`
      sleep 1
      assert dead?(pid)
    end
  end

  def test_kill_9_following_timeout
    Dir.chdir(SERVERS) do
      `./stubborn_server.rb start`
      sleep 1
      pid = reported_pid 'stubborn_server'
      assert alive?(pid)
      Process.kill 'TERM', pid
      sleep 1
      assert alive?(pid)
      `./stubborn_server.rb stop`
      assert dead?(pid)
    end
  end
end
