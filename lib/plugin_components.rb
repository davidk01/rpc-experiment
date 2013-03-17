# Each plugin should be self-documenting as far as
# possible and all the various classes for the self-documenting
# pieces should go here.
module PluginComponents

  class Plugin
    attr_reader :plugin, :description

    def initialize(klass, description); @plugin, @description = klass, description; end

    def action_exists?(action); !@plugin.actions[action].nil?; end

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
