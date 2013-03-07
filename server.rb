require 'msgpack'
require 'socket'
require 'thread'
require 'resolv'
require 'resolv-replace'
require 'nio'
require 'celluloid'

# die as soon as possible
Thread.abort_on_exception = true

class DoubleRegistrationAttempt < StandardError; end
class Registrar
  include Celluloid
  
  def initialize
    @registry = {}
  end
  
  def register(opts = {})
    fqdn = opts[:payload]["fqdn"]
    abort DoubleRegistrationAttempt.new("#{fqdn} tried to double register.") if @registry[fqdn]
    opts[:payload]["connection"] = opts[:connection]
    opts[:payload]["heartbeat_timestamp"] = Time.now.to_i
    @registry[fqdn] = opts[:payload]
  end
  
  def connection(fqdn)
    @registry[fqdn]["connection"]
  end
  
  def delete(fqdn)
    @registry[fqdn]["connection"].close
    @registry.delete(fqdn)
  end
  
  def filter(&blk)
    fqdn_accumulator = []
    @registry.each {|fqdn, data| fqdn_accumulator << fqdn if blk.call(fqdn, data)}
    fqdn_accumulator
  end
end

module ServerRegistrationHearbeatStateMachine

  @registry = Registrar.new
  @heartbeat_selector, @connection_registration_lock = NIO::Selector.new, Mutex.new
  
  def self.start
    puts "Starting server registration state machine."
    start_registration_listener; start_heartbeat_select_loop; start_culling_loop
  end
  
  # set up registration handling
  def self.start_registration_listener
    Thread.new do
      puts "Listening for registration requests."
      Socket.tcp_server_loop(3000) do |conn|
        Thread.new { registration_handler(conn) }
      end
    end
  end
  
  def self.start_heartbeat_select_loop
    puts "Starting heartbeat select loop."
    Thread.new do 
      loop do
        @connection_registration_lock.synchronize do
          @heartbeat_selector.select(1) {|m| m.value.call}
        end
        sleep 1
      end
    end
  end
  
  # handle registration requests
  def self.registration_handler(connection)
    puts "Handling registration."
    payload = MessagePack.unpack(connection.gets.strip)
    begin
      @registry.register(:payload => payload, :connection => connection)
    rescue DoubleRegistrationAttempt
      puts "Double registration attempt. Cleaning up and retrying."
      fqdn = payload["fqdn"]
      @heartbeat_selector.deregister(@registry.connection(fqdn))
      @registry.delete(fqdn); retry
    end
    puts "Adding connection to selector loop."
    @connection_registration_lock.synchronize do
      heartbeat_monitor = @heartbeat_selector.register(connection, :r)
      puts "Connection added to selector loop."
      heartbeat_monitor.value = proc do
        puts "Reading heartbeat data."
        heartbeat = (heartbeat_monitor.io.gets || "").strip
        if heartbeat == "OK"
          puts "#{payload["fqdn"]} still chugging along."
          payload["heartbeat_timestamp"] = Time.now.to_i
        else
          puts "Something went wrong with #{payload["fqdn"]}."
          puts "Received message: #{heartbeat}."
          puts "Removing it from select loop and registry."
          @heartbeat_selector.deregister(connection)
          @registry.async.delete(payload["fqdn"])
        end
      end
    end
  end
  
  # anything older than 5 minutes dies
  def self.start_culling_loop
    puts "Starting connection killer."
    Thread.new do
      loop do
        sleep 120; puts "Culling registrants.";
        @registry.filter do |fqdn, data|
          Time.now.to_i - data["heartbeat_timestamp"] > 5 * 60
        end.each do |fqdn|
          @heartbeat_selector.deregister(@registry.connection(fqdn))
          @registry.async.delete(fqdn)
        end
      end
    end
  end
end

ServerRegistrationHearbeatStateMachine.start
sleep