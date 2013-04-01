['msgpack', 'resolv', 'resolv-replace', 'socket', 'celluloid', 
 'logger'].each { |e| require e }
['./dispatcher', './action_payload', '../lib/plugin_components', 
 '../lib/plugins'].each { |e| require_relative e }
$logger = Logger.new(STDOUT, 'daily'); Thread.abort_on_exception = true

$agent_config = {
  :registration_server => 'localhost', :registration_server_port => 3000,
  :agent_dispatch_port => 3001, :registration_wait_period => 5,
  :heartbeat_interval => 5
}

module ClientRegistrationHeartbeatStateMachine
  
  def self.start
    Thread.new { register; establish_heartbeat }
    accept_rpc_requests
  end
  
  # TODO: Make the agent dispatch port configurable
  # TODO: Make the retry frequency configurable
  def self.register
    begin
      @conn = Socket.tcp($agent_config[:registration_server], 
        $agent_config[:registration_server_port])
      $logger.debug "Registering."
      payload = {
        "agent_dispatch_port" => $agent_config[:agent_dispatch_port]
      }.to_msgpack
      @conn.write [payload.length].pack("*i") + payload
    rescue Errno::ECONNREFUSED, Errno::EPIPE
      wait_period = $agent_config[:registration_wait_period]
      $logger.error "Registration connection refused or broken. Retrying in #{wait_period} seconds."
      sleep wait_period; retry
    end
  end
  
  # TODO: Make heartbeat frequency configurable
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
  
  # TODO: Make rpc port configurable and the same
  # as what is sent out during the registration attempt.
  def self.accept_rpc_requests
    exceptions = [ArgumentError, MessagePack::MalformedFormatError,
      Dispatcher::PluginExistenceError, Dispatcher::ActionSupportedError]
    Thread.new do
      $logger.info "Accepting rpc requests."
      dispatcher = Dispatcher.new
      Socket.tcp_server_loop($agent_config[:agent_dispatch_port]) do |conn|
        $logger.debug "Action dispatch connection accepted."
        # TODO: Unpacking can fail so figure out how to handle that
        # TODO: Make sure dispatcher does validation
        begin
          results = dispatcher.dispatch(ActionPayload.new(conn.gets.strip)).to_msgpack
          # TODO: This can fail so make it more robust, e.g. broken pipe, connection reset, etc.
          # TODO: Define the interface between plugins and dispatchers, in other words
          # the plugins don't need to know anything about the serialization format, all
          # the metadata and other stuff should be handled by the dispatcher with some
          # extra help from some other objects.
          # TODO: Clean up the exception handling mechanism, dispatcher errors should be handled
          # internally and should not propagate up to the connection layer.
          conn.write [results.length].pack("*i") + results
        rescue *exceptions => e
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
