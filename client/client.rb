require 'socket'
require 'msgpack'

require_relative '../lib/actionpayload'
require_relative '../lib/fiberdsl'

class Client

  class Agent
    
    def initialize(fqdn, port); @fqdn, @port = fqdn, port; end
    
    # open a connection to the dispatch port and send the request
    def act(plugin, action, arguments = {})
      Socket.tcp(@fqdn, @port) do |sock|
        payload =  ActionPayload.new("plugin" => plugin, "action" => action, "arguments" => arguments)
        sock.puts payload.serialize
        reader = PartialReaderDSL::FiberReaderMachine.protocol do
          consume(4) { |buff| buff.unpack("*i")[0] }
          consume { |buff| MessagePack.unpack buff }
        end
        # TODO: None blocking isn't always the best approach
        # think of a way to add blocking behavior
        while (res = reader.call(sock)).nil?
          sleep 0.1; res = reader.call(sock)
        end
        res[0]
      end
    end

  end

  attr_reader :agents

  def initialize(opts = {})
    [:registration_server, :query_port].each do |e|
      raise ArgumentError, "#{e} is a required argument." if opts[e].nil?
    end
    Socket.tcp(opts[:registration_server], opts[:query_port]) do |sock|
      payload = {"request_type" => "agent_discovery"}.to_msgpack
      sock.write [payload.length].pack("*i") + payload
      reader = PartialReaderDSL::FiberReaderMachine.protocol do
        consume(4) { |buff| buff.unpack("*i")[0] }
        consume { |buff| MessagePack.unpack(buff)["agents"] }
      end
      while (res = reader.call(sock)).nil?
        sleep 0.1; reader.call(sock)
      end
      @agents = res[0].map { |agent_data| Agent.new(*agent_data) }
    end
  end
  
end
