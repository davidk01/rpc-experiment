class DoubleRegistrationAttempt < StandardError; end

class Registrar
  
  class Registrant
    attr_reader :connection
    def initialize(opts = {})
      [:payload, :connection].each do |e|
        raise ArgumentError, "#{e} is a required argument." if opts[e].nil?
      end
      @connection, @payload = opts[:connection], opts[:payload]
    end
    
    def fqdn
      @payload["fqdn"]
    end
    
    def latest_timestamp
      @payload["heartbeat_timestamp"]
    end
    
    def refresh_timestamp
      @payload["heartbeat_timestamp"] = Time.now.to_i
    end
  end

end

class Registrar
  include Celluloid
  
  def initialize
    @registry = {}
  end
  
  def register(opts = {})
    if @registry[fqdn = (registrant = Registrant.new(opts)).fqdn]
      abort DoubleRegistrationAttempt.new("#{fqdn} tried to double register.")
    else
      registrant.refresh_timestamp; @registry[fqdn] = registrant
    end
  end
  
  def connection(fqdn)
    @registry[fqdn].connection
  end
  
  def delete(fqdn)
    @registry[fqdn].connection.close; @registry.delete(fqdn)
  end
  
  def beat(fqdn)
    @registry[fqdn].refresh_timestamp
  end
end