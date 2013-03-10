# We don't like double registrations but I'm not sure
# what the proper course of action is. Right now the
# second registration attempt is denied.
class DoubleRegistrationAttempt < StandardError; end

class Registrar
  
  # Payloads are hashmaps but hashmaps are too maleable
  # so all payloads should follow the pattern of encapsulating
  # them with a class that limits access. This class is one simple
  # example of that pattern.
  class Registrant
    attr_reader :connection
    
    def initialize(payload, connection)
      @connection, @payload = connection, payload
    end
    
    def fqdn
      @fqdn ||= connection.remote_address.getnameinfo[0]
    end
    
    def latest_timestamp
      @payload["heartbeat_timestamp"]
    end
    
    def refresh_timestamp
      @payload["heartbeat_timestamp"] = Time.now.to_i
    end
    
  end

end

# Used within NIOActor to manage registered agents. Each registrant
# knows what it needs to know about itself so after registration only
# the fqdn should be necessary to do anything.
class Registrar

  def initialize
    @registry = {}
  end
  
  def register(payload, connection)
    if @registry[fqdn = (registrant = Registrant.new(payload, connection)).fqdn]
      raise DoubleRegistrationAttempt.new("#{fqdn} tried to double register.")
    else
      registrant.refresh_timestamp; @registry[fqdn] = registrant
    end
  end
  
  def each
    @registry.each
  end
  
  def connection(fqdn)
    @registry[fqdn].connection
  end
  
  def delete(fqdn)
    @registry.delete(fqdn)
  end
  
  def beat(fqdn)
    @registry[fqdn].refresh_timestamp
  end
  
end