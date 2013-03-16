['msgpack', 'socket', 'thread', 'resolv', 'resolv-replace', 'nio', 'celluloid', 
 'logger', 'timeout'].each { |e| require e }
['./registrar', './nioactor', './heartbeatcallback', 
 '../lib/fiberdsl'].each { |e| require_relative e }
$logger = Logger.new(STDOUT, 'daily'); Thread.abort_on_exception = true
$config = {
  :registration_port => 3000,
  :registration_timeout => 5, # seconds
  :connection_killer_interval => 120, # seconds
  :agent_staleness => 5 # minutes
}

module ServerRegistrationHeartbeatStateMachine
  
  class RegistrationTimeout < StandardError; end
  
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
      Socket.tcp_server_loop($config[:registration_port]) do |conn|
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
      payload = registration_message_deserializer(connection)
    rescue MessagePack::MalformedFormatError
      $logger.error "MessagePack couldn't parse message: #{serialized_payload}."
      $logger.warn "Malformed data."; connection.close
    rescue RegistrationTimeout
      $logger.error "Registration timed out."; connection.close
    rescue EOFError
      $logger.error "Couldn't read enough of the registration message."; connection.close
    else
      @heartbeat_selector.register_connection(payload, connection)
    end
  end
  
  # TODO: Make the registration timeout configurable
  def self.registration_message_deserializer(connection)
    machine = PartialReaderDSL::FiberReaderMachine.protocol do
      consume(4) do |buff| 
        len = buff.unpack("*i")[0]
        $logger.debug "Message length: #{len}."
        len
      end
      consume do |buff| 
        payload = MessagePack.unpack(buff)
        $logger.debug "Payload: #{payload}."
        payload
      end
    end
    Timeout::timeout($config[:registration_timeout], RegistrationTimeout) do
      res = machine.call(connection) while res.nil?
      return res[0]
    end
  end
  
  def self.read_partial_until(wanted_buffer_length, connection)
    $logger.debug "Wanted buffer length: #{wanted_buffer_length}."
    buffer = ""
    while (current_buff_length = buffer.length) < wanted_buffer_length
      $logger.debug "Current buffer length: #{current_buff_length}."
      buffer << connection.readpartial(wanted_buffer_length - current_buff_length)
    end
    buffer
  end
  
  # anything older than 5 minutes dies
  # TODO: Make the culling time configurable
  # TODO: Make the culling frequency configurable
  def self.culling_loop
    $logger.debug "Starting connection killer."
    staleness_interval = $config[:agent_staleness] * 60
    culler = proc {|registrant| Time.now.to_i - registrant.latest_timestamp > staleness_interval}
    Thread.new do
      loop do
        sleep $config[:connection_killer_interval]; $logger.debug "Culling registrants."
        @heartbeat_selector.filter(&culler)
      end
    end
  end
  
end

ServerRegistrationHeartbeatStateMachine.start
sleep
