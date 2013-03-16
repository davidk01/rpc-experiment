# Each plugin should be self-documenting as far as
# possible and all the various classes for the self-documenting
# pieces should go here.
module PluginComponents
  
  class Plugin
    attr_reader :plugin, :description
    def initialize(klass, description)
      @plugin, @description = klass, description
    end
  end
  
  # stores various bits about the action, e.g. name, arguments
  class ActionMetadata
    def initialize(opts = {})
      [:name, :desc, :args].each do |e|
        raise ArgumentError, "#{e} is required." if opts[e].nil?
      end
      @name, @description, @arguments = opts[:name], opts[:desc], opts[:args]
    end
    
    # basic argument validation that happens during dispatch time
    def validate_args(opts = {})
      @arguments.each do |e|
        if opts[e].nil?
          raise ArgumentError, "#{e} is a required argument for #{@name}."
        end
      end
    end
  end
  
end

# Simple plugin management system that uses various module hooks
# to handle plugin registration and plugin action definition.
module Plugins

  class PluginDefinedTwiceError < StandardError; end
  
  @plugins = {}
  
  def self.plugins
    @plugins.keys.clone
  end
  
  def self.plugin_exists?(plugin)
    !@plugins[plugin].nil?
  end

  def self.action_supported?(plugin, action)
    !(plugin_data = @plugins[plugin]).nil? && plugin_data.plugin.action_exists?(action)
  end

  def self.validate_arguments(plugin, action, args)
    @plugins[plugin].plugin.actions[action].validate_args(args)
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
    
    def action_exists?(action)
      !@actions[action].nil?
    end

    def actions
      @actions
    end
  end
  
end
