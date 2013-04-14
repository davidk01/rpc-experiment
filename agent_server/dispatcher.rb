require_relative '../lib/dispatchresponsepayload'
require_relative '../lib/dispatcherrorpayload'

$logger = Logger.new(STDOUT, 'daily'); $logger.level = Logger::DEBUG
Thread.abort_on_exception = true

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
    unless (plugin = Plugins[payload.plugin])
      return ErrorResponse.new(:error_message => "#{payload.plugin} does not exist.")
    end
    unless (plugin.action_exists?(action = payload.action))
      return ErrorResponse.new(:error_message => "#{payload.plugin} does not support #{action}.")
    end
    begin
      $logger.debug "Getting response: plugin = #{payload.plugin}, action = #{action}."
      ResponsePayload.new(:plugin_response => plugin.act(action, payload.arguments))
    rescue Exception => e
      ErrorResponse.new(:error_message => e.message)
    end
  end

end
