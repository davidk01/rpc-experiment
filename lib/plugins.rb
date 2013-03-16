# Simple plugin management system that uses various module hooks
# to handle plugin registration and plugin action definition.
module Plugins

  class PluginDefinedTwiceError < StandardError; end
  
  @plugins = {}
  
  def self.plugins
    @plugins.keys.clone
  end

  def self.[](plugin)
    @plugins[plugin]
  end
  
  def self.included(base)
    if @plugins[base.descriptive_name]
      raise PluginDefinedTwiceError, "#{base.descriptive_name} is already defined."
    end
    @plugins[base.descriptive_name] = PluginComponents::Plugin.new(base, base.description)
    base.instance_variable_set(:@actions, {}); base.extend(PluginClassMethods)
  end
  
  module PluginClassMethods

    def def_action(opts = {}, &blk)
      @actions[method_name = opts[:name]] = PluginComponents::ActionMetadata.new(opts)
      self.instance_eval { define_method(method_name, &blk) }
    end

    def actions
      @actions
    end

  end
  
end
