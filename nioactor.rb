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
    @selector_loop.select(1) {|m| m.value.call}
  end
  
  def wipe(fqdn)
    $logger.warn "Wiping #{fqdn}."
    connection = @registry.connection(fqdn)
    @selector_loop.deregister(connection); @registry.delete(fqdn); connection.close
  end
  
  def loop_registration(connection)
    fqdn = connection.remote_address.getnameinfo[0]
    $logger.debug "Adding connection to selector loop."
    heartbeat_monitor = @selector_loop.register(connection, :r)
    $logger.debug "Connection added to selector loop."
    heartbeat_monitor.value = proc do
      $logger.debug "Reading heartbeat data."
      heartbeat = (heartbeat_monitor.io.gets || "").strip
      if heartbeat == "OK"
        $logger.debug "#{fqdn} doing OK."; @registry.beat(fqdn)
      else
        $logger.error "Message from #{fqdn}: #{heartbeat}."; wipe(fqdn)
      end
    end
  end
  
  # TODO: Clean this up a little bit doesn't feel as clean as it should
  def register_connection(payload, connection)
    begin
      @registry.register(:payload => payload, :connection => connection)
    rescue DoubleRegistrationAttempt => e
      $logger.error e.message; $logger.warn "Closing connection: #{connection}."
      connection.close; return
    end
    loop_registration(connection)
  end
  
end