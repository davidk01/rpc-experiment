class Discovery
  require 'yaml'

  # every plugin needs a name
  def self.descriptive_name
    "host.discovery"
  end

  # every plugin should also have a description
  def self.description
    <<-EOF
      Provides host facts and responds to ping requests so
      that we can verify that an agent is indeed running.
      This information can also be exposed via the heartbeat
      mechanism but this plugin serves as a demonstration of
      how plugins are structured.
    EOF
  end

  # register as a plugin
  include Plugins

  # define some actions
  def_action :name => "ping", :desc => "The agent responds with pong.", 
   :args => [] do |opts = {}| 
    "pong"
  end

  def_action :name => "fact_filter", :desc => [
    "The agent looks in its local fact store",
    "and responds with either yes or no based",
    "on whether the fact matches or not."
  ].join(" "), :args => ["fact", "value"] do |opts = {}|
    facts = YAML.load_file('/etc/host_facts.yaml')
    facts[opts["fact"]] == opts["value"]
  end

  def_action :name => "facts", :desc => [
    "Takes the host facts and ships it back",
    "wholesale. The idea is that the client can",
    "use this information to do filtering with",
    "the full power of ruby instead of some gimped DSL."
  ].join(" "), :args => [] do |opts = {}|
    YAML.load_file('/etc/host_facts.yaml')
  end

end
