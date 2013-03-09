class NIOActor
  include Celluloid
  
  def initialize
    @selector_loop, @registry = NIO::Selector.new, Registrar.new
  end
  
  def filter(&blk)
    @registry.each do |fqdn, registrant|
      if blk.call(fqdn, registrant)
        $logger.warn "Closing connection: #{fqdn}."
        wipe(fqdn)
      end
    end
  end
  
  def tick
    @selector_loop.select(1) {|m| m.value.call}
  end
  
  def wipe(fqdn, connection = @registry.connection(fqdn))
    $logger.warn "Wiping #{fqdn}."
    @selector_loop.deregister(connection); @registry.delete(fqdn); connection.close
  end
  
  def register_connection(payload, fqdn, connection)
    begin
      @registry.register(:payload => payload, :connection => connection)
    rescue Exception => e
      abort e
    end
    $logger.debug "Adding connection to selector loop."
    heartbeat_monitor = @selector_loop.register(connection, :r)
    $logger.debug "Connection added to selector loop."
    heartbeat_monitor.value = proc do
      $logger.debug "Reading heartbeat data."
      heartbeat = (heartbeat_monitor.io.gets || "").strip
      if heartbeat == "OK"
        $logger.debug "#{fqdn} doing OK."; @registry.beat(fqdn)
      else
        $logger.error "Message from #{fqdn}: #{heartbeat}."
        wipe(fqdn, connection)
      end
    end
  end
end