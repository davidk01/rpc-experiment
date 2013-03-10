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
  
  # Spawn a thread for each registration request because
  # we don't want to limit how many registrations we can
  # handle at a time.
  def self.start_registration_listener
    Thread.new do
      $logger.debug "Listening for registration requests."
      # TODO: Make the registration port configurable
      Socket.tcp_server_loop(3000) do |conn|
        Thread.new { registration_handler(conn) }
      end
    end
  end
  
  def self.heartbeat_select_loop
    $logger.debug "Starting heartbeat select loop."
    Thread.new { loop { @heartbeat_selector.tick } }
  end
  
  def self.registration_handler(connection)
    $logger.debug "Registration request: #{connection}."
    begin
      payload_length = connection.readpartial(4).unpack("*i")[0]
      serialized_payload = connection.readpartial(payload_length)
      payload = MessagePack.unpack(serialized_payload)
    rescue MessagePack::MalformedFormatError
      $logger.error "MessagePack couldn't parse message: #{serialized_payload}."
      $logger.warn "Closing registration connection because of malformed data."
      connection.close
    else
      @heartbeat_selector.register_connection(payload, connection)
    end
  end
  
  # TODO: Registration should follow some well defined protocol
  def self.validate_payload(args)
    #code
  end
  
  # anything older than 5 minutes dies
  # TODO: Make the culling time configurable
  # TODO: Make the culling frequency configurable
  def self.culling_loop
    $logger.debug "Starting connection killer."
    culler = proc {|registrant| Time.now.to_i - registrant.latest_timestamp > 5 * 60}
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