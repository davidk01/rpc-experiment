['pry', 'msgpack', 'socket', 'thread', 'resolv', 'resolv-replace', 'nio', 'celluloid', 
 'logger', 'timeout'].each { |e| require e }

['./registrar', './nioactor', './heartbeatcallback', 
 '../lib/fiberdsl'].each { |e| require_relative e }

$config = {
  :log_location => STDOUT, :log_level => Logger::DEBUG,
  :registration_port => 3000, :registration_timeout => 5, # seconds
  :query_port => 3001,
  :connection_killer_interval => 120, # seconds
  :agent_staleness => 5 # minutes
}

$logger = Logger.new($config[:log_location], 'daily'); $logger.level = $config[:log_level]

Thread.abort_on_exception = true

module ServerRegistrationHeartbeatStateMachine
  
  class RegistrationTimeout < StandardError; end
  
  @heartbeat_selector = NIOActor.new

  def self.start
    start_registration_listener; start_query_listener;
    heartbeat_select_loop; culling_loop
  end
  
  def self.start_query_listener
    Thread.new do
      $logger.debug "Starting query listener on #{$config[:query_port]}."
      Socket.tcp_server_loop($config[:query_port]) do |conn|
        $logger.debug "Accepted query connection."
        payload_length = conn.read(4).unpack("*i")[0]
        payload = MessagePack.unpack(conn.read(payload_length))
        $logger.debug "Query unpacked."
        case payload["request_type"]
        when "agent_discovery"
          agents = @heartbeat_selector.live_agents
          payload = {"agents" => agents}.to_msgpack
          conn.write [payload.length].pack("*i") + payload
        end
        conn.flush; conn.close
      end
    end
  end

  def self.start_registration_listener
    Thread.new do
      Socket.tcp_server_loop($config[:registration_port]) do |conn|
        Thread.new { registration_handler(conn) }
      end
    end
  end
  
  def self.heartbeat_select_loop; Thread.new { loop { @heartbeat_selector.tick } }; end
  
  def self.registration_handler(connection)
    begin
      payload = registration_message_deserializer(connection)
      exit if payload.nil?
    rescue MessagePack::MalformedFormatError
      $logger.error "MessagePack couldn't parse message: #{serialized_payload}."
      connection.close
    rescue RegistrationTimeout
      $logger.error "Registration timed out."; connection.close
    rescue EOFError
      $logger.error "Couldn't read enough of the registration message."; connection.close
    else
      @heartbeat_selector.register_connection(payload, connection)
    end
  end
  
  def self.registration_message_deserializer(connection)
    m = PartialReaderDSL::FiberReaderMachine.protocol do
      consume(4) { |buff| buff.unpack("*i")[0] }; consume { |buff| MessagePack.unpack(buff) }
    end
    Timeout::timeout($config[:registration_timeout], RegistrationTimeout) do
      loop { if (res = m.call(connection)).nil? then sleep 1 else return res[0] end }
    end
  end
  
  def self.culling_loop
    staleness_interval = $config[:agent_staleness] * 60
    culler = proc { |registrant| Time.now.to_i - registrant.latest_timestamp > staleness_interval }
    Thread.new do
      loop { sleep $config[:connection_killer_interval]; @heartbeat_selector.filter(&culler) }
    end
  end
  
end

ServerRegistrationHeartbeatStateMachine.start
sleep
