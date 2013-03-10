['msgpack', 'socket', 'thread', 'resolv', 'resolv-replace',
 'nio', 'celluloid', 'logger'].each {|e| require e}
['./registrar', './nioactor'].each {|e| require_relative e}
$logger = Logger.new(STDOUT, 'daily')
# die as soon as possible
Thread.abort_on_exception = true

module ServerRegistrationHeartbeatStateMachine
  
  @heartbeat_selector = NIOActor.new
  
  def self.start
    $logger.debug "Starting server registration state machine."
    start_registration_listener; heartbeat_select_loop; culling_loop
  end
  
  # set up registration handling
  def self.start_registration_listener
    Thread.new do
      $logger.debug "Listening for registration requests."
      Socket.tcp_server_loop(3000) do |conn|
        Thread.new { registration_handler(conn) }
      end
    end
  end
  
  def self.heartbeat_select_loop
    $logger.debug "Starting heartbeat select loop."
    Thread.new { loop { @heartbeat_selector.tick } }
  end
  
  # handle registration requests
  def self.registration_handler(connection)
    $logger.debug "Registration request: #{connection}."
    payload = MessagePack.unpack(connection.gets.strip)
    @heartbeat_selector.register_connection(payload, connection)
  end
  
  # anything older than 5 minutes dies
  def self.culling_loop
    $logger.debug "Starting connection killer."
    culler = proc {|fqdn, registrant| Time.now.to_i - registrant.latest_timestamp > 5 * 60}
    Thread.new do
      loop do
        sleep 120; $logger.debug "Culling registrants."
        @heartbeat_selector.filter(&culler)
      end
    end
  end
  
end

ServerRegistrationHeartbeatStateMachine.start
sleep