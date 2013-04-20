class ErrorResponse

  def initialize(opts = {})
    [:error_message].each do |e|
      raise ArgumentError, "#{e} is a required argument." if opts[e].nil?
    end
    @error_message = opts[:error_message]
  end

  def serialize
    payload = {:error => true, :error_message => @error_message}.to_json
    [payload.length].pack("*i") + payload
  end

end
