# Takes an RPC payload and does the right thing. The right thing
# things means always return some kind of result so all exceptions
# must be contained and not propagated to the agent that received
# the payload.
class Dispatcher
  
  def initialize(plugin_path)
    # load all the plugins at the given path, i.e. load all .rb files
  end
  
  def dispatch(payload)
    #code
  end
end