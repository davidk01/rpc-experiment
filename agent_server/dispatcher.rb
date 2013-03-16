class Dispatcher
  
  class PluginExistenceError < StandardError; end
  class ActionSupportedError < StandardError; end

  def initialize
    directory = File.dirname(__FILE__)
    plugin_directory = File.absolute_path(directory + "/../plugins")
    $logger.debug "Plugin directory: #{plugin_directory}."
    Dir[plugin_directory + '/*.rb'].each do |plugin| 
      $logger.debug "Loading plugin: #{plugin}."; require plugin
    end
  end
  
  def validate(payload)
    $logger.debug "Validating payload."
    unless (p = Plugins[payload.plugin])
      raise PluginExistenceError, "#{payload.plugin} does not exist"
    end
    unless p.action_exists?(payload.action)
      raise ActionSupportedError, "#{payload.plugin} does not support #{payload.action}."
    end
    p.plugin.actions[payload.action].validate_args(payload.arguments)
  end

  def dispatch(payload)
    validate(payload)
    plugin, action, arguments = payload.plugin, payload.action, payload.arguments
    $logger.debug "Dispatching #{action} on #{plugin} with #{arguments}."
    Plugins[plugin].plugin.new.send(action, arguments)
  end

end
