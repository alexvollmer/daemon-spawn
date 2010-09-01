require "test/unit"
require "tmpdir"

class Test::Unit::TestCase
  def pid_file(daemon_name)
    File.join Dir.tmpdir, "#{daemon_name}.pid"
  end
  
  def possible_pid(daemon_name)
    `ps x | grep ruby | grep #{daemon_name} | awk '{ print $1 }'`.to_i
  end
  
  def reported_pid(daemon_name)
    IO.read(pid_file(daemon_name)).to_i
  end
  
  def alive?(pid)
    Process.kill 0, pid
  rescue Errno::ESRCH
    false
  end
  
  def dead?(pid)
    not alive? pid
  end
end
