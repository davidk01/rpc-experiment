module Plugins
  class NoPluginError < StandardError; end
  
  @plugins = Hash.new {|h, k| h[k] = {}}
  
  def self.plugins
    @plugins.keys.clone
  end
  
  def [](plugin)
    if !(plugin_data = @plugins[plugin])
      raise NoPluginError, "%s does not exist." % [plugin]
    end
    plugin_data["class"]
  end
  
  def self.included(base)
    @plugins[base.name] = base
    base.instance_variable_set(:@actions, {})
    base.extend(PluginClassMethods)
    base.instance_eval { include InstanceMethods }
  end
  
  module PluginClassMethods
    def def_action(opts = {}, &blk)
      name, description = opts[:name], opts[:desc]
      @actions[name] = description
      self.instance_eval { define_method(name, &blk) }
    end
  end
  
  module PluginInstanceMethods
  end
  
end
