require "socket"
require "test/unit"

class DaemonSpawnTest < Test::Unit::TestCase

  SERVERS = File.join(File.dirname(__FILE__), "servers")

  def with_socket
    socket = TCPSocket.new('localhost', 5150)
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
        assert_raises(Errno::ECONNREFUSED) { TCPSocket.new('localhost', 5150) }
      end
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

end
