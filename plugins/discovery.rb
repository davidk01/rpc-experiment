class Discovery
  
  # describe the plugin
  def self.descriptive_name
    "host.discovery"
  end

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
   :args => {} do |opts = {}| 
    "pong"
  end

end
