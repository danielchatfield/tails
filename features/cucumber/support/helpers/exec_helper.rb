require 'json'
require 'socket'

class VMCommand

  attr_reader :returncode, :stdout, :stderr

  def initialize(vm, cmd, options = {})
    options[:user] ||= "root"
    options[:spawn] ||= false
    ret = VMCommand.execute(vm, cmd, options[:user], options[:spawn])
    @returncode = ret[0]
    @stdout = ret[1]
    @stderr = ret[2]
  end

  def VMCommand.wait_until_remote_shell_is_up(vm, timeout = 30)
    begin
      SystemTimer.timeout(timeout) do
        self.execute(vm, "true", "root", false)
      end
    rescue Timeout::Error
      raise "Remote shell seems to be down"
    end
  end

  # The parameter `cmd` cannot contain newlines. Separate multiple
  # commands using ";" instead.
  # If `spawn` is false the server will block until it has finished
  # executing `cmd`. If it's true the server won't block, and the
  # response will always be [0, "", ""] (only used as an
  # ACK). execute() will always block until a response is received,
  # though. Spawning is useful when starting processes in the
  # background (or running scripts that does the same) like the
  # vidalia-wrapper, or any application we want to interact with.
  def VMCommand.execute(vm, cmd, user, spawn)
    type = spawn ? "spawn" : "call"
    socket = TCPSocket.new("127.0.0.1", vm.get_remote_shell_port)
    begin
      socket.puts(JSON.dump([type, user, cmd]))
      s = socket.readline(sep = "\0").chomp("\0")
    ensure
      socket.close
    end
    begin
      return JSON.load(s)
    rescue JSON::ParserError
      # The server often returns something unparsable for the very
      # first execute() command issued after a VM start/restore
      # (generally from wait_until_remote_shell_is_up()) presumably
      # because the TCP -> serial link isn't properly setup yet. All
      # will be well after that initial hickup, so we just retry.
      return VMCommand.execute(vm, cmd, user, spawn)
    end
  end

  def success?
    return @returncode == 0
  end

end
