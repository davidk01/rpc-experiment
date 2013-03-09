class Dispatcher
  include Celluloid
  
  def initialize(plugin_path)
    # load all the plugins at the given path, i.e. load all .rb files
  end
  
  def dispatch(payload)
    #code
  end
end