require 'msgpack'
require 'socket'
require 'thread'
require 'resolv'
require 'resolv-replace'
require 'nio'
require 'celluloid'
require 'logger'
require_relative './registrar'
require_relative './nioactor'
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
    fqdn = payload["fqdn"] = connection.remote_address.getnameinfo[0]
    begin
      @heartbeat_selector.register_connection(payload, fqdn, connection)
    rescue DoubleRegistrationAttempt
      $logger.error "Double registration attempt. Cleaning up and retrying."
      @heartbeat_selector.wipe(fqdn); retry
    end
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