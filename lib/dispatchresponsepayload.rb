class ResponsePayload

  def initialize(opts = {})
    [:plugin_response].each do |e|
      raise ArgumentError, "#{e} is a required argument." if opts[e].nil?
    end
    @plugin_response = opts[:plugin_response]
  end

  def serialize
    payload = {:error => false, :plugin_response => @plugin_response}.to_json
    [payload.length].pack("*i") + payload
  end

end
