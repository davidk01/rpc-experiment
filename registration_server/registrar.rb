class DoubleRegistrationAttempt < StandardError; end

class Registrar
  
  class Registrant
    attr_reader :connection
    
    def initialize(payload, connection); @connection, @payload = connection, payload; end
    
    def fqdn; @fqdn ||= connection.remote_address.getnameinfo[0]; end
    
    def latest_timestamp; @payload["heartbeat_timestamp"]; end
    
    def refresh_timestamp; @payload["heartbeat_timestamp"] = Time.now.to_i; end
    
  end

end

class Registrar

  def initialize; @registry = {}; end
  
  def register(payload, connection)
    if @registry[fqdn = (registrant = Registrant.new(payload, connection)).fqdn]
      raise DoubleRegistrationAttempt, "#{fqdn} tried to double register."
    else
      registrant.refresh_timestamp; @registry[fqdn] = registrant
    end
  end
  
  def each; @registry.each; end
  
  def connection(fqdn); @registry[fqdn].connection; end
  
  def delete(fqdn); @registry.delete(fqdn); end
  
  def beat(fqdn); @registry[fqdn].refresh_timestamp; end
  
end
