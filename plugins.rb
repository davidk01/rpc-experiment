module Plugins
  class NoPluginError < StandardError; end
  class PluginDefinedTwiceError < StandardError; end
  
  class Plugin
    attr_reader :class, :description
    def initialize(klass, description)
      @class, @description = klass, description
    end
  end
  
  @plugins = {}
  
  def self.plugins
    @plugins.keys.clone
  end
  
  def self.[](plugin)
    if !(plugin_data = @plugins[plugin])
      raise NoPluginError, "%s does not exist." % [plugin]
    end
    plugin_data
  end
  
  def self.included(base)
    if @plugins[base.descriptive_name]
      raise PluginDefinedTwiceError, "#{base.descriptive_name} is already defined."
    end
    base.instance_variable_set(:@actions, {}); base.extend(PluginClassMethods)
  end
  
  module PluginClassMethods
    def def_action(opts = {}, &blk)
      name, description = opts[:name], opts[:desc]
      @actions[name] = description
      self.instance_eval { define_method(name, &blk) }
    end
    
    def actions
      @actions
    end
  end
end
