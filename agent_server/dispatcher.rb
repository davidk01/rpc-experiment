class ResponsePayload

  def initialize(opts = {})
    [:plugin_response].each do |e|
      raise ArgumentError, "#{e} is a required argument." if opts[e].nil?
    end
    @plugin_response = opts[:plugin_response]
  end

  def serialize
    payload = {:error => false, :plugin_response => @plugin_response}.to_msgpack
    [payload.length].pack("*i") + payload
  end

end

class ErrorResponse

  def initialize(opts = {})
    [:error_message].each do |e|
      raise ArgumentError, "#{e} is a required argument." if opts[e].nil?
    end
    @error_message = opts[:error_message]
  end

  def serialize
    payload = {:error => true, :error_message => @error_message}.to_msgpack
    [payload.length].pack("*i") + payload
  end

end

class Dispatcher

  def initialize
    directory = File.dirname(__FILE__)
    plugin_directory = File.absolute_path(directory + "/../plugins")
    $logger.debug "Plugin directory: #{plugin_directory}."
    Dir[plugin_directory + '/*.rb'].each do |plugin| 
      $logger.debug "Loading plugin: #{plugin}."; require plugin
    end
  end

  def dispatch(payload)
    $logger.debug "Validating plugin and action existence."
    unless (plugin_metadata = Plugins[payload.plugin])
      return ErrorResponse.new(:error_message => "#{payload.plugin} does not exist.")
    end
    unless (plugin_metadata.action_exists?(action = payload.action))
      return ErrorResponse.new(:error_message => "#{payload.plugin} does not support #{payload.action}.")
    end
    begin
      $logger.debug "Validating arguments."
      plugin_metadata.plugin.actions[action].validate_args(arguments = payload.arguments)
      $logger.debug "Getting response: plugin = #{payload.plugin}, action = #{action}."
      plugin_response = plugin_metadata.plugin.new.send(action, arguments)
      ResponsePayload.new(:plugin_response => plugin_response)
    rescue Exception => e
      ErrorResponse.new(:error_message => e.message)
    end
  end

end
