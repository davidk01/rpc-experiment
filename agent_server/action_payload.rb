class ActionPayload

  attr_reader :plugin, :action, :arguments
  def initialize(payload)
    payload_hash = MessagePack.unpack(payload)
    ["plugin", "action", "arguments"].each do |e|
      if (val = payload_hash[e]).nil?
        raise ArgumentError, "#{e} is a required argument."
      else
        instance_variable_set("@#{e}", val)
      end
    end
  end

end
