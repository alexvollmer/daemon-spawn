require File.join(File.dirname(__FILE__), "helper")
require "tempfile"

class MultiDaemonSpawnTest < Test::Unit::TestCase

  SERVERS = File.join(File.dirname(__FILE__), "servers")

  def setup
    @tmpfile = Tempfile.new("multi_daemon_spawn_test")
  end

  def tear_down
    @tmpfile.delete
  end

  def simple_server(*args)
    `./simple_server.rb #{args.join(" ")}`
  end

  def current_pids
    regexp = /SimpleServer is running \(PID (\d+)\)/
    pids = simple_server("status").split("\n").map do |line|
      if m = regexp.match(line)
        m[1]
      else
        nil
      end
    end.compact
  end

  def while_running
    Dir.chdir(SERVERS) do
      simple_server "stop"
      simple_server "start", @tmpfile.path
      sleep 1
      begin
        yield if block_given?
      ensure
        simple_server "stop"
      end
    end
  end

  def test_start_multiple
    while_running do
      lines = open(@tmpfile.path).readlines
      assert_equal 2, lines.size
      assert lines.member?("SimpleServer (0) started\n")
      assert lines.member?("SimpleServer (1) started\n")
    end
  end

  def test_status_multiple
    while_running do
      lines = simple_server("status").split("\n")
      lines.each do |line|
        assert_match /SimpleServer is running/, line
      end
    end
  end

  def test_stop_multiple
    while_running
    Dir.chdir(SERVERS) do
      assert_match /No PIDs found/, simple_server("status")
    end
  end

  def test_restart_multiple
    while_running do
      pids = current_pids
      simple_server "restart"
      new_pids = current_pids
      assert_not_equal pids.sort, new_pids.sort
    end
  end

  def test_status_with_one_dead_process
    while_running do
      pids = current_pids
      Process.kill(9, pids[0].to_i)

      lines = simple_server("status").split("\n")
      assert_equal 2, lines.size
      assert lines.member?("SimpleServer is NOT running (PID #{pids[0]})")
      assert lines.member?("SimpleServer is running (PID #{pids[1]})")
    end
  end

  def test_restart_with_one_dead_process
    while_running do
      pids = current_pids
      Process.kill(9, pids[0].to_i)

      lines = simple_server("restart").split("\n")
      assert lines.member?("PID file found, but process was not running. The daemon may have died."), lines.inspect
      assert_equal 2, lines.select { |l| l == "SimpleServer started." }.size

      new_pids = current_pids
      assert_not_equal new_pids, pids
    end
  end

  def test_start_after_started
    while_running do
      pids = current_pids
      assert_match(/Daemons already started! PIDS: #{pids.join(', ')}/,
                   simple_server("start"))
    end
  end
end
