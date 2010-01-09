require "test/unit"
$:.unshift(File.join(File.dirname(__FILE__), "..", "examples"))
require "echo_server"

class DaemonSpawnTest < Test::Unit::TestCase

  EXAMPLES = File.join(File.dirname(__FILE__), "..", "examples")

  def while_running
    Dir.chdir(EXAMPLES) do
      `./echo_server.rb stop`
      assert_match(/EchoServer started./, `./echo_server.rb start 5150`)
      socket = TCPSocket.new('localhost', 5150)
      socket.setsockopt(Socket::SOL_SOCKET,
                         Socket::SO_RCVTIMEO,
                         [1, 0].pack("l_2"))

      yield(socket) if block_given?

      socket.close
      assert_match(//, `./echo_server.rb stop`)
      assert_raises(Errno::ECONNREFUSED) { TCPSocket.new('localhost', 5150) }
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
    Dir.chdir(EXAMPLES) do
      assert_match(/EchoServer is NOT running/, `./echo_server.rb status`)
    end
  end

  def test_start_after_started
    while_running do |socket|
      assert_match(/An instance of EchoServer is already running/,
                   `./echo_server.rb start 5150 2>&1`)
    end
  end

  def test_stop_after_stopped
    Dir.chdir(EXAMPLES) do
      assert_match("Pid file not found. Is the daemon started?",
                   `./echo_server.rb stop`)
    end
  end

end
