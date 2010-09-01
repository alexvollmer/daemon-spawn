require "socket"
require "test/unit"
require "tmpdir"

class DaemonSpawnTest < Test::Unit::TestCase

  SERVERS = File.join(File.dirname(__FILE__), "servers")

  def pidfile
    File.join Dir.tmpdir, 'echo_server.pid'
  end

  # Try to make sure no pidfile (or process) is left over from another test.
  def setup
    begin
      Process.kill 9, `ps x | grep ruby | grep echo_server.rb | awk '{ print $1 }'`.to_i
    rescue Errno::ESRCH
      # good, no process to kill
    end
    begin
      File.unlink pidfile
    rescue Errno::ENOENT
      # good, no pidfile to clear
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

  def while_running
    Dir.chdir(SERVERS) do
      `./echo_server.rb stop`
      assert_match(/EchoServer started./, `./echo_server.rb start 5150`)
      sleep 1
      begin
        with_socket
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
      leftover_pid = IO.read(pidfile).to_i
      Process.kill 9, leftover_pid
      sleep 1
      assert_raises(Errno::ESRCH) do
        Process.kill 0, leftover_pid
      end
      assert File.exists?(pidfile)
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
      new_pid = IO.read(pidfile).to_i
      assert new_pid != leftover_pid
      assert_nothing_raised do
        Process.kill 0, new_pid
      end
    end
  end
  
  def test_restart_after_daemon_dies_leaving_pid_file
    after_daemon_dies_leaving_pid_file do |leftover_pid|
      assert_match /EchoServer started/, `./echo_server.rb restart 5150`
      sleep 1
      new_pid = IO.read(pidfile).to_i
      assert new_pid != leftover_pid
      assert_nothing_raised do
        Process.kill 0, new_pid
      end
    end
  end

end
