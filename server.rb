require 'msgpack'
require 'socket'
require 'thread'
require 'resolv'
require 'resolv-replace'
require 'nio'

# die as soon as possible
Thread.abort_on_exception = true

class DoubleRegistrationAttempt < StandardError; end

module ServerRegistrationHearbeatStateMachine
  # keep track of agents
  @registry_lock = Mutex.new
  @registry = {}
  @heartbeat_selector = NIO::Selector.new
  
  def self.start
    puts "Starting server registration state machine."
    start_registration_listener; start_heartbeat_select_loop; start_culling_loop
  end
  
  # set up registration handling
  def self.start_registration_listener
    Thread.new do
      puts "Listening for registration requests."
      Socket.tcp_server_loop(3000) do |conn|
        Thread.new do
          registration_handler(conn)
        end
      end
    end
  end
  
  def self.start_heartbeat_select_loop
    puts "Starting heartbeat select loop."
    # this is pretty weird. there is a lock on @heartbeat_selector that is set when select is
    # called so we can not register anything until that lock is released and the way thread
    # scheduling works out it is possible to keep coming back to this loop and reacquring the
    # lock before the registration handler thread gets a chance to add it to the select loop
    # that's why we need "sleep 1" at the end of the loop. we need to give other threads a
    # chance to acquire the select loop lock and register heartbeat sockets.
    Thread.new do 
      loop { @heartbeat_selector.select(1) {|m| m.value.call}; sleep 1 }
    end
  end
  
  # handle registration requests
  def self.registration_handler(connection)
    puts "Handling registration."
    payload = connection.gets.strip
    payload = MessagePack.unpack(payload)
    payload["connection"] = connection
    @registry_lock.synchronize do
      # make sure no double registration happens because that will leak
      # connections in @heartbeat_selector event loop
      if @registry[payload["fqdn"]]
        raise DoubleRegistrationAttempt, "#{payload["fqdn"]} tried to register more than once."
      end
      puts "Registering #{payload["fqdn"]}."
      @registry[payload["fqdn"]] = payload
    end
    # add heartbeat connection to NIO select loop
    puts "Adding connection to selector loop."
    heartbeat_monitor = @heartbeat_selector.register(connection, :r)
    puts "Connection added to selector loop."
    heartbeat_monitor.value = proc do
      puts "Reading heartbeat data."
      # need to be careful if client closes connection while we try to read
      heartbeat = (heartbeat_monitor.io.gets || "").strip
      if heartbeat == "OK"
        puts "#{payload["fqdn"]} still chugging along."
        payload["heartbeat_timestamp"] = Time.now.to_i
      else
        puts "Something went wrong with #{payload["fqdn"]}."
      end
    end
  end
  
  # every 2 minutes go through the list of registered
  # agents and verify that they are up
  def self.start_culling_loop
    puts "Starting connection killer."
    Thread.new do
      loop do
        sleep 120
        puts "Culling registrants."
        now = Time.now.to_i
        @registry_lock.synchronize do
          need_to_die = []
          # collect who needs to die
          @registry.each do |fqdn, data|
            if now - data["heartbeat_timestamp"] > 5 * 60
              puts "#{fqdn} hasn't sent a heartbeat in more than 5 minutes."
              puts "Removing #{fqdn} from registry."
              need_to_die << fqdn
            else
              puts "#{fqdn} is chugging along."
            end
          end
          # unregister, close, delete
          need_to_die.each do |fqdn|
            conn = @registry[fqdn]["connection"]
            @heartbeat_selector.deregister(conn)
            conn.close; @registry.delete(fqdn)
          end
        end
      end
    end
  end
end

ServerRegistrationHearbeatStateMachine.start
sleep