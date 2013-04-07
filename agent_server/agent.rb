['msgpack', 'resolv', 'resolv-replace', 'socket', 'celluloid', 
 'logger'].each { |e| require e }

['./dispatcher', '../lib/plugin_components', 
 '../lib/plugins', '../lib/actionpayload',
 '../lib/registrationpayload'].each { |e| require_relative e }

$logger = Logger.new(STDOUT, 'daily'); Thread.abort_on_exception = true

$agent_config = {
  :registration_server => 'localhost', :registration_server_port => 3000,
  :agent_dispatch_port => 3002, :registration_wait_period => 5,
  :heartbeat_interval => 5
}

module ClientRegistrationHeartbeatStateMachine
  
  def self.start
    Thread.new { register; establish_heartbeat }; accept_rpc_requests
  end
  
  def self.register
    begin
      @conn = Socket.tcp($agent_config[:registration_server], $agent_config[:registration_server_port])
      payload = RegistrationPayload.new(:dispatch_port => $agent_config[:agent_dispatch_port])
      @conn.write payload.serialize
    rescue Errno::ECONNREFUSED, Errno::EPIPE
      wait_period = $agent_config[:registration_wait_period]
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
          sleep $agent_config[:heartbeat_interval]
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
      Socket.tcp_server_loop($agent_config[:agent_dispatch_port]) do |conn|
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
