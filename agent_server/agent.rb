['msgpack', 'resolv', 'resolv-replace', 'socket', 'celluloid', 
 'logger', 'trollop'].each { |e| require e }

['./dispatcher', '../lib/plugin_components', 
 '../lib/plugins', '../lib/actionpayload',
 '../lib/registrationpayload'].each { |e| require_relative e }

$logger = Logger.new(STDOUT, 'daily')
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
      @conn = Socket.tcp($opts["registration.server"], $opts["registration.server.port"])
      payload = RegistrationPayload.new(:dispatch_port => $opts["agent.dispatch.port"])
      @conn.write payload.serialize
    rescue Errno::ECONNREFUSED, Errno::EPIPE
      wait_period = $opts["registration.wait.period"]
      $logger.error "Registration connection refused or broken. Retrying in #{wait_period} seconds."
      sleep wait_period; retry
    end
  end
  
  def self.establish_heartbeat
    Thread.new do
      loop do
        $logger.debug "Heartbeat."
        begin
          @conn.write "OK"; @conn.flush
          sleep $opts["heartbeat.wait.period"]
        rescue Errno::EPIPE
          $logger.error "Looks like the registry died."; break
        rescue Errno::ECONNRESET
          $logger.error "Registry closed connection on us."; break
        end
      end
      restart_heartbeat
    end
  end
  
  def self.restart_heartbeat
    $logger.info "Re-establishing heartbeat."
    register; establish_heartbeat
  end
  
  # as what is sent out during the registration attempt.
  def self.accept_rpc_requests
    Thread.new do
      $logger.info "Accepting rpc requests."
      dispatcher = Dispatcher.new
      Socket.tcp_server_loop($opts["agent.dispatch.port"]) do |conn|
        $logger.debug "Action dispatch connection accepted."
        begin
          # this is the only line that can throw an exception
          result = dispatcher.dispatch ActionPayload.deserialize(conn.gets.strip)
          conn.write result.serialize
        rescue MessagePack::MalformedFormatError => e
          $logger.error e
        ensure
          conn.flush; conn.close
        end
      end
    end
  end
  
end

ClientRegistrationHeartbeatStateMachine.start
sleep
