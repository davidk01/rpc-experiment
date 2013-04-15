require_relative '../lib/dispatchresponsepayload'
require_relative '../lib/dispatcherrorpayload'

Thread.abort_on_exception = true

class Dispatcher

  def initialize
    directory = File.dirname(__FILE__)
    plugin_directory = File.absolute_path(directory + "/../plugins")
    Dir[plugin_directory + '/*.rb'].each do |plugin| 
      puts "Loading plugin: #{plugin}."; require plugin
    end
  end

  def dispatch(payload)
    unless (plugin = Plugins[payload.plugin])
      return ErrorResponse.new(:error_message => "#{payload.plugin} does not exist.")
    end
    unless (plugin.action_exists?(action = payload.action))
      return ErrorResponse.new(:error_message => "#{payload.plugin} does not support #{action}.")
    end
    begin
      puts "Getting response: plugin = #{payload.plugin}, action = #{action}."
      ResponsePayload.new(:plugin_response => plugin.act(action, payload.arguments))
    rescue Exception => e
      ErrorResponse.new(:error_message => e.message)
    end
  end

end
