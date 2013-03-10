# Each plugin should be self-documenting as far as
# possible and all the various classes for the self-documenting
# pieces should go here.
module PluginComponents

  class ActionArgumentRequiredError < StandardError; end
  
  class Plugin
    attr_reader :class, :description
    def initialize(klass, description)
      @class, @description = klass, description
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
    
    # basic argument validation for now
    def validate_args(opts = {})
      @arguments.each do |e|
        if opts[e].nil?
          raise ActionArgumentRequiredError, "#{e} is a required argument for #{@name}."
        end
      end
    end
  end
  
end

# Simple plugin management system that uses various module hooks
# to handle plugin registration and plugin action definition.
module Plugins

  class NoPluginError < StandardError; end
  class PluginDefinedTwiceError < StandardError; end
  
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
    @plugins[base.descriptive_name] = PluginComponents::Plugin.new(base, base.description)
    base.instance_variable_set(:@actions, {}); base.extend(PluginClassMethods)
  end
  
  module PluginClassMethods
    def def_action(opts = {}, &blk)
      @actions[name] = PluginComponents::ActionMetadata.new(opts)
      self.instance_eval { define_method(name, &blk) }
    end
    
    def actions
      @actions
    end
  end
  
end