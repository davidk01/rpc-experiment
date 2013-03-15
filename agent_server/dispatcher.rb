class Dispatcher
  
  def initialize(plugin_path)
    Dir[plugin_path + '/**/*.rb'].each { |plugin| require plugin }
  end
  
  def dispatch(payload)
    plugin, action, arguments = payload.plugin, payload.action, payload.arguments
    $logger.debug "Dispatching #{action} on #{plugin} with #{arguments}."
    Plugins[plugin].new.send(action, arguments)
  end
end
