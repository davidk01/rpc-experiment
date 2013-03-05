require 'msgpack'
require 'socket'
require 'thread'
require 'resolv'
require 'resolv-replace'

# keep track of agents
@registry_lock = Mutex.new
@registry = {}

# every so often we need to make sure the agents
# we think are up are actually up
def cull_registry
  @registry_lock.synchronize do
    @registry.reject! do |fqdn, data|
      puts "Checking agent status: #{fqdn}."
      Socket.tcp(fqdn, data["heartbeat_port"]) do |conn|
        heartbeat_response = conn.read
        if heartbeat_response != "OK"
          puts "#{fqdn} is out of commission."; true
        else
          puts "#{fqdn} still chugging along."; false
        end
      end
    end
  end
end

# handle registration requests
def registration_handler(connection)
  payload = MessagePack.unpack(connection.read)
  @registry_lock.synchronize do
    puts "Registering #{payload["fqdn"]}."
    @registry[payload["fqdn"]] = payload
  end
end

# set up registration handling
registration_thread = Thread.new do
  Socket.tcp_server_loop(3000) do |conn|
    puts "Listening for registration requests."
    Thread.new do
      puts "Handling registration request."
      registration_handler(conn)
      conn.close
    end
  end
end

# every 2 minutes go through the list of registered
# agents and verify that they are up
heartbeat_thread = Thread.new do
  loop do
    sleep 5
    puts "Checking heartbeats."
    cull_registry
  end
end

heartbeat_thread.join
registration_thread.join
