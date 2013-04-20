# registration is likely to evolve over time so encapsulate
class RegistrationPayload

  def initialize(opts = {})
    [:dispatch_port].each do |e|
      raise ArgumentError, "#{e} is a required argument." if opts[e].nil?
    end
    @dispatch_port = opts[:dispatch_port]
  end

  def serialize
    payload = {"agent_dispatch_port" => @dispatch_port}.to_json
    [payload.length].pack("*i") + payload
  end

end
