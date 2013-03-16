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
    unless Plugins.plugin_exists?(plugin = payload.plugin)
      raise PluginExistenceError, "#{plugin} does not exist"
    end
    unless Plugins.action_supported?(plugin, action = payload.action)
      raise ActionSupportedError, "#{plugin} does not support #{action}."
    end
    Plugins.validate_arguments(plugin, action, args = payload.arguments)
  end

  def dispatch(payload)
    validate(payload)
    plugin, action, arguments = payload.plugin, payload.action, payload.arguments
    $logger.debug "Dispatching #{action} on #{plugin} with #{arguments}."
    Plugins[plugin].plugin.new.send(action, arguments)
  end
end
