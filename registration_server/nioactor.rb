class NIOActor
  include Celluloid
  
  def initialize; @selector_loop, @registry = NIO::Selector.new, Registrar.new; end
  
  def filter(&blk)
    @registry.each do |fqdn, registrant|
      (puts "Closing connection: #{fqdn}."; wipe(fqdn)) if blk.call(registrant)
    end
  end
  
  def live_agents
    fqdns = []; @registry.each do |fqdn, registrant|
      fqdns << [fqdn, registrant.payload["agent_dispatch_port"]]
    end
    fqdns
  end

  def tick; @selector_loop.select(1) { |m| m.value.call(m) }; end
  
  def wipe(fqdn)
    puts "Wiping #{fqdn}."; @selector_loop.deregister(conn = @registry.connection(fqdn))
    @registry.delete(fqdn); conn.close
  end
  
  def beat(fqdn); @registry.beat(fqdn); end

  def attach_callback(monitor)
    fqdn = monitor.io.remote_address.ip_address
    monitor.value = HeartbeatCallback.new(proc { beat(fqdn) }, proc { wipe(fqdn) })
  end
  
  def register_connection(payload, connection)
    puts "Registering connection."
    begin
      @registry.register(payload, connection)
    rescue DoubleRegistrationAttempt => e
      puts e; puts "Closing connection: #{connection}."
      connection.close; return
    end
    attach_callback @selector_loop.register(connection, :r)
  end
  
end
