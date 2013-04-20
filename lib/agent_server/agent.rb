['json', 'resolv', 'resolv-replace', 'socket', 'celluloid', 
 'trollop'].each { |e| require e }

['agent_server/dispatcher', 'plugin_components', 
 'plugins', 'actionpayload',
 'registrationpayload'].each { |e| require e }

Thread.abort_on_exception = true

$opts = Trollop::options do

  opt "registration.server", "Required for heartbeat signal.", 
    :type => :string, :required => false

  opt "registration.server.port", "Default port is 3000.", 
    :type => :int, :required => false, :default => 3000

  opt "agent.dispatch.port", "The port that accepts rpc requests.", 
    :type => :int, :required => true

  opt "registration.wait.period", "Number of seconds to wait between registration attempts.", 
    :type => :int, :default => 5

  opt "heartbeat.wait.period", "Number of seconds to wait between heartbeat events.", 
    :type => :int, :default => 5

end

module ClientRegistrationHeartbeatStateMachine
  
  def self.start
    Thread.new { register; establish_heartbeat }; accept_rpc_requests
  end
  
  def self.register
    begin
      @conn = TCPSocket.new($opts["registration.server"], $opts["registration.server.port"])
      payload = RegistrationPayload.new(:dispatch_port => $opts["agent.dispatch.port"])
      @conn.write payload.serialize
    rescue Errno::ECONNREFUSED, Errno::EPIPE, Exception => e
      puts e.class
      wait_period = $opts["registration.wait.period"]
      puts "Registration connection refused or broken. Retrying in #{wait_period} seconds."
      sleep wait_period; retry
    end
  end
  
  def self.establish_heartbeat
    Thread.new do
      loop do
        begin
          @conn.write "OK"; @conn.flush
          sleep $opts["heartbeat.wait.period"]
        rescue Errno::EPIPE
          puts "Looks like the registry died."; break
        rescue Errno::ECONNRESET
          puts "Registry closed connection on us."; break
        end
      end
      restart_heartbeat
    end
  end
  
  def self.restart_heartbeat
    puts "Re-establishing heartbeat."
    register; establish_heartbeat
  end
  
  # as what is sent out during the registration attempt.
  def self.accept_rpc_requests
    Thread.new do
      dispatcher = Dispatcher.new
      puts "Starting dispatch listener: port = #{$opts["agent.dispatch.port"]}."
      listener = TCPServer.new('localhost', $opts["agent.dispatch.port"])
      while true
        conn = listener.accept
        puts "Action dispatch connection accepted."
        begin
          # this is the only line that can throw an exception
          result = dispatcher.dispatch ActionPayload.deserialize(conn.gets.strip)
          conn.write result.serialize
        rescue Exception => e
          puts e
        ensure
          conn.flush; conn.close
        end
      end
    end
  end
  
end

ClientRegistrationHeartbeatStateMachine.start
sleep
