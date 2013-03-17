# The whole point of this class is to handle registration and heartbeat
# related activities so anything that doesn't fall in those two buckets
# needs to go somewhere else.
class NIOActor
  include Celluloid
  
  def initialize
    @selector_loop, @registry = NIO::Selector.new, Registrar.new
  end
  
  def filter(&blk)
    @registry.each do |fqdn, registrant|
      ($logger.warn "Closing connection: #{fqdn}."; wipe(fqdn)) if blk.call(registrant)
    end
  end
  
  def tick
    @selector_loop.select(1) { |m| $logger.debug "Calling back #{m}."; m.value.call(m) }
  end
  
  def wipe(fqdn)
    $logger.warn "Wiping #{fqdn}."
    connection = @registry.connection(fqdn)
    @selector_loop.deregister(connection); @registry.delete(fqdn); connection.close
  end
  
  def attach_callback(monitor)
    fqdn = monitor.io.remote_address.getnameinfo[0]
    monitor.value = HeartbeatCallback.new(proc { @registry.beat(fqdn) }, proc { wipe(fqdn) })
  end
  
  def loop_registration(connection)
    $logger.debug "Adding connection to selector loop."
    heartbeat_monitor = @selector_loop.register(connection, :r)
    $logger.debug "Connection added to selector loop."
    attach_callback(heartbeat_monitor)
  end
  
  def register_connection(payload, connection)
    begin
      @registry.register(payload, connection)
    rescue DoubleRegistrationAttempt => e
      $logger.error e.message; $logger.warn "Closing connection: #{connection}."
      connection.close; return
    end
    loop_registration(connection)
  end
  
end
