['json', 'socket', 'thread', 'resolv', 'resolv-replace', 'nio', 'celluloid', 
 'timeout', 'trollop', 'pp'].each { |e| require e }

['./registrar', './nioactor', './heartbeatcallback', 
 '../fiberdsl'].each do |f|
  path = File.absolute_path(File.dirname(__FILE__) + '/' + f)
  puts "Requiring: #{path}."
  require path
end

$opts = Trollop::options do
  
  opt "registration.port", "The port that agents send heartbeat and registration requests to.",
    :required => true, :type => :int
  
  opt "registration.timeout", "How long to wait in seconds for the registration to complete.",
    :type => :int, :default => 5
  
  opt "query.port", "Clients connect to this port to get a list of agents.",
    :required => true, :type => :int

  opt "stale.heartbeat.time", "All connections that are this number of minutes old will be killed.",
    :type => :int, :default => 5

  opt "reaper.sleep.time", "Time in seconds between invocations of stale agent killer.",
    :type => :int, :default => 120

end

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
      listener = TCPServer.new($opts["query.port"])
      while true
        conn = listener.accept
        puts "Accepted query connection."
        reader = PartialReaderDSL::FiberReaderMachine.protocol(true) do
          consume(4) { |buff| buff.unpack("*i")[0] }
          consume { |buff| JSON.parse buff }
        end
        payload = reader.call(conn)[0]
        pp payload
        case payload["request_type"]
        when "agent_discovery"
          agents = @heartbeat_selector.live_agents
          payload = {"agents" => agents}.to_json
          conn.write [payload.length].pack("*i") + payload
        end
        conn.flush; conn.close
      end
    end
  end

  def self.start_registration_listener
    Thread.new do
      listener = TCPServer.new($opts["registration.port"])
      while true
        conn = listener.accept
        Thread.new { registration_handler(conn) }
      end
    end
  end
  
  def self.heartbeat_select_loop; Thread.new { loop { @heartbeat_selector.tick } }; end
  
  def self.registration_handler(connection)
    begin
      payload = registration_message_deserializer(connection)
    rescue JSON::ParserError => e
      puts "JSON couldn't parse message: #{e}."
      connection.close
    rescue RegistrationTimeout
      puts "Registration timed out."; connection.close
    rescue EOFError
      puts "Couldn't read enough of the registration message."; connection.close
    else
      @heartbeat_selector.register_connection(payload, connection)
    end
  end
  
  def self.registration_message_deserializer(connection)
    Timeout::timeout($opts["registration.timeout"], RegistrationTimeout) do
      count = connection.read(4).unpack("*i")[0]
      return JSON.parse connection.read(count)
    end
  end
  
  def self.culling_loop
    staleness_interval = $opts["stale.heartbeat.time"] * 60
    culler = proc { |registrant| Time.now.to_i - registrant.latest_timestamp > staleness_interval }
    Thread.new do
      loop { sleep $opts["reaper.sleep.time"]; @heartbeat_selector.filter(&culler) }
    end
  end
  
end

ServerRegistrationHeartbeatStateMachine.start
sleep
