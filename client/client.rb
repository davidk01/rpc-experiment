require 'socket'
require 'msgpack'

class Client

  class Agent
    
    def initialize(fqdn, port); @fqdn, @port = fqdn, port; end
    
    # TODO: Looks like I need to define a query language
    def filter(query); end

    # open a connection to the dispatch port and send the request
    def act(plugin, action, arguments = {}); end

  end

  def initialize(opts = {})
    [:registration_server, :query_port].each do |e|
      raise ArgumentError, "#{e} is a required argument." if opts[e].nil?
    end
    Socket.tcp(opts[:registration_server], opts[:query_port]) do |sock|
      payload = {"request_type" => "agent_discovery"}.to_msgpack
      sock.write [payload.length].pack("*i") + payload
      reply_length = sock.read(4).unpack("*i")[0]
      raw_agent_data = MessagePack.unpack(sock.read(reply_length))["agents"]
      @agents = raw_agent_data.map { |agent_data| Agent.new(*agent_data) }
    end
  end

  
end
